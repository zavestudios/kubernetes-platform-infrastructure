data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  common_tags = merge(
    {
      managed-by = "terraform"
      purpose    = "alb-behavior-lab"
      repository = "kubernetes-platform-infrastructure"
      temporary  = "true"
      ttl-hours  = tostring(var.ttl_hours)
    },
    var.tags,
  )

  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  log_bucket_name    = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "6.7.3"

  name = "${var.name_prefix}-vpc"
  cidr = "10.42.0.0/16"

  azs            = local.availability_zones
  public_subnets = ["10.42.0.0/24", "10.42.1.0/24"]

  enable_dns_hostnames    = true
  enable_dns_support      = true
  enable_nat_gateway      = false
  map_public_ip_on_launch = false

  manage_default_network_acl    = false
  manage_default_route_table    = false
  manage_default_security_group = false

  public_subnet_tags = {
    tier = "public"
  }
}

resource "aws_security_group" "ec2" {
  name        = "${var.name_prefix}-ec2"
  description = "Allow the ALB to reach the lab EC2 target"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "ec2_from_alb" {
  security_group_id            = aws_security_group.ec2.id
  referenced_security_group_id = module.alb.security_group_id
  description                  = "HTTP from the lab ALB"
  from_port                    = 8080
  to_port                      = 8080
  ip_protocol                  = "tcp"
}

resource "aws_instance" "target" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = "t3.nano"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = false
  vpc_security_group_ids      = [aws_security_group.ec2.id]

  user_data_replace_on_change = true
  user_data                   = <<-USER_DATA
    #!/bin/bash
    set -euo pipefail

    install -d -m 0755 /opt/alb-lab

    cat >/opt/alb-lab/server.py <<'PYTHON'
    import json
    from http.server import BaseHTTPRequestHandler, HTTPServer


    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            status = 200
            body = {"backend": "ec2", "path": self.path}

            if self.path == "/health":
                body = {"status": "healthy", "backend": "ec2"}
            elif self.path == "/ec2/fail":
                status = 503
                body = {"status": "intentional failure", "backend": "ec2"}

            payload = json.dumps(body).encode()
            self.send_response(status)
            self.send_header("content-type", "application/json")
            self.send_header("content-length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        def log_message(self, format, *args):
            return


    HTTPServer(("0.0.0.0", 8080), Handler).serve_forever()
    PYTHON

    cat >/etc/systemd/system/alb-lab.service <<'UNIT'
    [Unit]
    Description=ALB behavior lab target
    After=network.target

    [Service]
    Type=simple
    ExecStart=/usr/bin/python3 /opt/alb-lab/server.py
    Restart=always
    RestartSec=2
    User=nobody
    Group=nobody
    NoNewPrivileges=true
    PrivateTmp=true

    [Install]
    WantedBy=multi-user.target
    UNIT

    systemctl daemon-reload
    systemctl enable --now alb-lab.service
  USER_DATA

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  root_block_device {
    encrypted   = true
    volume_size = 8
    volume_type = "gp3"
  }

  tags = {
    Name = "${var.name_prefix}-target"
  }
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/function.zip"
}

data "aws_iam_policy_document" "lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "${var.name_prefix}-lambda"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${var.name_prefix}"
  retention_in_days = 7
}

resource "aws_lambda_function" "target" {
  function_name = var.name_prefix
  description   = "Lambda target for the disposable ALB behavior lab"
  role          = aws_iam_role.lambda.arn
  runtime       = "python3.13"
  handler       = "index.handler"

  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256

  timeout     = 5
  memory_size = 128

  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda_basic_execution,
  ]
}

resource "aws_s3_bucket" "alb_logs" {
  bucket        = local.log_bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_ownership_controls" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id

  rule {
    id     = "expire-lab-logs"
    status = "Enabled"

    filter {}

    expiration {
      days = 7
    }
  }
}

data "aws_iam_policy_document" "alb_logs" {
  statement {
    sid     = "AllowALBLogDelivery"
    actions = ["s3:PutObject"]
    resources = [
      "${aws_s3_bucket.alb_logs.arn}/alb/AWSLogs/${data.aws_caller_identity.current.account_id}/*",
    ]

    principals {
      type        = "Service"
      identifiers = ["logdelivery.elasticloadbalancing.amazonaws.com"]
    }

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values = [
        "arn:${data.aws_partition.current.partition}:elasticloadbalancing:${var.aws_region}:${data.aws_caller_identity.current.account_id}:loadbalancer/*",
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "alb_logs" {
  bucket = aws_s3_bucket.alb_logs.id
  policy = data.aws_iam_policy_document.alb_logs.json
}

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "10.5.1"

  name               = var.name_prefix
  load_balancer_type = "application"
  vpc_id             = module.vpc.vpc_id
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false

  access_logs = {
    bucket = aws_s3_bucket.alb_logs.id
    prefix = "alb"
  }

  security_group_ingress_rules = {
    http = {
      description = "Public HTTP for the lab"
      from_port   = 80
      to_port     = 80
      ip_protocol = "tcp"
      cidr_ipv4   = "0.0.0.0/0"
    }
  }

  security_group_egress_rules = {
    ec2 = {
      description = "HTTP to targets in the lab VPC"
      from_port   = 8080
      to_port     = 8080
      ip_protocol = "tcp"
      cidr_ipv4   = module.vpc.vpc_cidr_block
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      fixed_response = {
        content_type = "application/json"
        message_body = jsonencode({ error = "no matching listener rule" })
        status_code  = "404"
      }

      rules = {
        lambda = {
          priority = 10
          actions = [{
            forward = {
              target_group_key = "lambda"
            }
          }]
          conditions = [{
            path_pattern = {
              values = ["/lambda", "/lambda/*"]
            }
          }]
        }

        ec2 = {
          priority = 20
          actions = [{
            forward = {
              target_group_key = "ec2"
            }
          }]
          conditions = [{
            path_pattern = {
              values = ["/ec2", "/ec2/*"]
            }
          }]
        }
      }
    }
  }

  target_groups = {
    lambda = {
      name_prefix              = "lmb-"
      target_type              = "lambda"
      target_id                = aws_lambda_function.target.arn
      attach_lambda_permission = true

      health_check = {
        enabled = false
      }
    }

    ec2 = {
      name_prefix = "ec2-"
      protocol    = "HTTP"
      port        = 8080
      target_type = "instance"
      target_id   = aws_instance.target.id

      health_check = {
        enabled             = true
        path                = "/health"
        matcher             = "200"
        interval            = 15
        healthy_threshold   = 2
        unhealthy_threshold = 2
        timeout             = 5
      }
    }
  }

  depends_on = [aws_s3_bucket_policy.alb_logs]
}

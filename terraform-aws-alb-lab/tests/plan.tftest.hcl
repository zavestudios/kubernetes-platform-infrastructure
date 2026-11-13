mock_provider "aws" {
  mock_data "aws_iam_policy_document" {
    defaults = {
      json = jsonencode({
        Version   = "2012-10-17"
        Statement = []
      })
    }
  }
}

run "plan_disposable_alb_lab" {
  command = plan

  override_data {
    target = data.aws_availability_zones.available
    values = {
      names = ["us-west-2a", "us-west-2b"]
    }
  }

  override_data {
    target = data.aws_caller_identity.current
    values = {
      account_id = "123456789012"
      arn        = "arn:aws:iam::123456789012:user/test"
      user_id    = "AIDATEST"
    }
  }

  override_data {
    target = data.aws_partition.current
    values = {
      dns_suffix = "amazonaws.com"
      partition  = "aws"
    }
  }

  override_data {
    target = data.aws_ami.amazon_linux_2023
    values = {
      id = "ami-0123456789abcdef0"
    }
  }

  assert {
    condition     = length(local.availability_zones) == 2
    error_message = "The ALB must span two availability zones."
  }

  assert {
    condition     = length(module.vpc.public_subnets) == 2
    error_message = "The ALB must span two public subnets."
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

locals {
  common_tags = merge(
    {
      managed-by = "terraform"
      purpose    = "alb-behavior-lab-bootstrap"
      repository = var.github_repository
    },
    var.tags,
  )

  state_bucket_name     = "${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-tfstate"
  github_subject_legacy = "repo:${var.github_organization}/${var.github_repository}"
  github_subject_immutable = (
    "repo:${var.github_organization}@${var.github_organization_id}/${var.github_repository}@${var.github_repository_id}"
  )
  oidc_provider_arn = var.create_github_oidc_provider ? (
    aws_iam_openid_connect_provider.github[0].arn
  ) : var.github_oidc_provider_arn
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.state_bucket_name

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  url             = "https://token.actions.githubusercontent.com"
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

data "aws_iam_policy_document" "plan_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.github_subject_legacy}:pull_request",
        "${local.github_subject_legacy}:ref:refs/heads/main",
        "${local.github_subject_immutable}:pull_request",
        "${local.github_subject_immutable}:ref:refs/heads/main",
      ]
    }
  }
}

data "aws_iam_policy_document" "deploy_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values = [
        "${local.github_subject_legacy}:environment:${var.github_environment}",
        "${local.github_subject_immutable}:environment:${var.github_environment}",
      ]
    }
  }
}

resource "aws_iam_role" "plan" {
  name               = "${var.name_prefix}-plan"
  assume_role_policy = data.aws_iam_policy_document.plan_assume_role.json
}

resource "aws_iam_role" "deploy" {
  name               = "${var.name_prefix}-deploy"
  assume_role_policy = data.aws_iam_policy_document.deploy_assume_role.json
}

data "aws_iam_policy_document" "state_read_and_lock" {
  statement {
    sid = "ListStateBucket"
    actions = [
      "s3:GetBucketLocation",
      "s3:ListBucket",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid = "ReadStateAndManageLocks"
    actions = [
      "s3:DeleteObject",
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.terraform_state.arn}/aws-alb-lab/lab.tfstate",
      "${aws_s3_bucket.terraform_state.arn}/aws-alb-lab/lab.tfstate.tflock",
    ]
  }
}

resource "aws_iam_role_policy" "plan_state" {
  name   = "${var.name_prefix}-state"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.state_read_and_lock.json
}

resource "aws_iam_role_policy" "deploy_state" {
  name   = "${var.name_prefix}-state"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.state_read_and_lock.json
}

data "aws_iam_policy_document" "plan" {
  statement {
    sid = "ReadLabResourceMetadata"
    actions = [
      "ec2:Describe*",
      "elasticloadbalancing:Describe*",
      "iam:Get*",
      "iam:List*",
      "lambda:Get*",
      "lambda:List*",
      "logs:Describe*",
      "sts:GetCallerIdentity",
    ]
    resources = ["*"]
  }

  statement {
    sid = "ReadLabLogBucket"
    actions = [
      "s3:GetBucket*",
      "s3:GetLifecycleConfiguration",
      "s3:GetObject*",
      "s3:ListBucket",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs/*",
    ]
  }
}

resource "aws_iam_role_policy" "plan" {
  name   = "${var.name_prefix}-read"
  role   = aws_iam_role.plan.id
  policy = data.aws_iam_policy_document.plan.json
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid = "ManageNetworkAndLoadBalancing"
    actions = [
      "ec2:AssociateRouteTable",
      "ec2:AttachInternetGateway",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateInternetGateway",
      "ec2:CreateRoute",
      "ec2:CreateRouteTable",
      "ec2:CreateSecurityGroup",
      "ec2:CreateSubnet",
      "ec2:CreateTags",
      "ec2:CreateVpc",
      "ec2:DeleteInternetGateway",
      "ec2:DeleteRoute",
      "ec2:DeleteRouteTable",
      "ec2:DeleteSecurityGroup",
      "ec2:DeleteSubnet",
      "ec2:DeleteTags",
      "ec2:DeleteVpc",
      "ec2:Describe*",
      "ec2:DetachInternetGateway",
      "ec2:DisassociateRouteTable",
      "ec2:ModifySubnetAttribute",
      "ec2:ModifyVpcAttribute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetRulePriorities",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
    ]
    resources = ["*"]
  }

  statement {
    sid     = "ManageLabLambda"
    actions = ["lambda:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:lambda:${var.aws_region}:${data.aws_caller_identity.current.account_id}:function:${var.name_prefix}*",
    ]
  }

  statement {
    sid     = "ManageLabLogs"
    actions = ["logs:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/${var.name_prefix}*",
    ]
  }

  statement {
    sid     = "ManageLabBuckets"
    actions = ["s3:*"]
    resources = [
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs",
      "arn:${data.aws_partition.current.partition}:s3:::${var.name_prefix}-${data.aws_caller_identity.current.account_id}-${var.aws_region}-logs/*",
    ]
  }

  statement {
    sid = "ManageLabRoles"
    actions = [
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:DetachRolePolicy",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListInstanceProfilesForRole",
      "iam:ListRolePolicies",
      "iam:PassRole",
      "iam:PutRolePolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:UpdateAssumeRolePolicy",
    ]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:role/${var.name_prefix}*",
    ]
  }

  statement {
    sid       = "ReadAccountAndImages"
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }

  statement {
    sid     = "CreateELBServiceLinkedRole"
    actions = ["iam:CreateServiceLinkedRole"]
    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/*",
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:AWSServiceName"
      values   = ["elasticloadbalancing.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "deploy" {
  name   = "${var.name_prefix}-deploy"
  role   = aws_iam_role.deploy.id
  policy = data.aws_iam_policy_document.deploy.json
}

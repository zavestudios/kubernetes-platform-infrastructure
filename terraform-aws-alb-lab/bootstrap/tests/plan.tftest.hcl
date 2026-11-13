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

run "plan_pipeline_bootstrap" {
  command = plan

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

  assert {
    condition     = aws_s3_bucket_versioning.terraform_state.versioning_configuration[0].status == "Enabled"
    error_message = "Remote Terraform state must have bucket versioning enabled."
  }

  assert {
    condition     = local.state_bucket_name == "zavestudios-alb-lab-123456789012-us-west-2-tfstate"
    error_message = "The state bucket name must be deterministic for this account and Region."
  }
}

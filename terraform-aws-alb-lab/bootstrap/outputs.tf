output "state_bucket_name" {
  description = "S3 bucket used by the lab's remote Terraform backend."
  value       = aws_s3_bucket.terraform_state.id
}

output "aws_account_id" {
  description = "AWS account permitted by the GitHub Actions credential step."
  value       = data.aws_caller_identity.current.account_id
}

output "plan_role_arn" {
  description = "Read-only GitHub Actions role used for speculative plans."
  value       = aws_iam_role.plan.arn
}

output "deploy_role_arn" {
  description = "GitHub Actions role used by approved apply and destroy jobs."
  value       = aws_iam_role.deploy.arn
}

output "github_environment" {
  description = "GitHub environment that must protect deployment jobs."
  value       = var.github_environment
}

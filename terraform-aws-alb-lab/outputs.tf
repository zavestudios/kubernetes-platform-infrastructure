output "alb_dns_name" {
  description = "Public DNS name of the lab ALB."
  value       = module.alb.dns_name
}

output "ec2_url" {
  description = "URL routed to the EC2 target."
  value       = "http://${module.alb.dns_name}/ec2"
}

output "lambda_url" {
  description = "URL routed to the Lambda target."
  value       = "http://${module.alb.dns_name}/lambda"
}

output "intentional_ec2_503_url" {
  description = "URL whose EC2 target intentionally returns HTTP 503."
  value       = "http://${module.alb.dns_name}/ec2/fail"
}

output "access_log_bucket" {
  description = "S3 bucket receiving ALB access logs."
  value       = aws_s3_bucket.alb_logs.id
}

output "target_group_arns" {
  description = "Target groups used in the behavior lab."
  value       = { for name, target_group in module.alb.target_groups : name => target_group.arn }
}

variable "aws_region" {
  description = "AWS Region containing the Terraform state bucket."
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix used for bootstrap resources and deployment roles."
  type        = string
  default     = "zavestudios-alb-lab"
}

variable "github_organization" {
  description = "GitHub organization trusted by the OIDC roles."
  type        = string
  default     = "zavestudios"
}

variable "github_organization_id" {
  description = "Permanent GitHub organization ID used in immutable OIDC subjects."
  type        = number
  default     = 259492171
}

variable "github_repository" {
  description = "GitHub repository trusted by the OIDC roles."
  type        = string
  default     = "kubernetes-platform-infrastructure"
}

variable "github_repository_id" {
  description = "Permanent GitHub repository ID used in immutable OIDC subjects."
  type        = number
  default     = 1138527441
}

variable "github_environment" {
  description = "Protected GitHub environment trusted by the deployment role."
  type        = string
  default     = "aws-alb-lab"
}

variable "create_github_oidc_provider" {
  description = "Create the account-wide GitHub Actions OIDC provider. Set false when one already exists."
  type        = bool
  default     = true
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub Actions OIDC provider ARN when create_github_oidc_provider is false."
  type        = string
  default     = null

  validation {
    condition     = var.create_github_oidc_provider || var.github_oidc_provider_arn != null
    error_message = "github_oidc_provider_arn is required when create_github_oidc_provider is false."
  }
}

variable "tags" {
  description = "Additional tags to apply to bootstrap resources."
  type        = map(string)
  default     = {}
}

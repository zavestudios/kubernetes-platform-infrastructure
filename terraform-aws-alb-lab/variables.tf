variable "aws_region" {
  description = "AWS Region in which to create the ALB lab."
  type        = string
  default     = "us-west-2"
}

variable "name_prefix" {
  description = "Prefix used for lab resource names."
  type        = string
  default     = "zavestudios-alb-lab"

  validation {
    condition     = length(var.name_prefix) <= 24 && can(regex("^[a-z0-9-]+$", var.name_prefix))
    error_message = "name_prefix must contain only lowercase letters, numbers, and hyphens and be at most 24 characters."
  }
}

variable "ttl_hours" {
  description = "Declared maximum lifetime of a deployment; used as a cost-control tag and operating contract."
  type        = number
  default     = 24

  validation {
    condition     = var.ttl_hours >= 1 && var.ttl_hours <= 72
    error_message = "ttl_hours must be between 1 and 72."
  }
}

variable "tags" {
  description = "Additional tags to apply to lab resources."
  type        = map(string)
  default     = {}
}

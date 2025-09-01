variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "jump_server_access_cidrs" {
  description = "CIDR blocks that can access jump server"
  type        = list(string)
}

variable "ha" {
  description = "High availability flag"
  type        = bool
  default     = false
}

variable "cso_files_bucket_arn" {
  description = "ARN of the S3 bucket containing CSO files"
  type        = string
}
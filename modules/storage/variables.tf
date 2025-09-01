variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnets" {
  description = "Private subnets for EFS mount targets"
  type        = map(object({
    id = string
  }))
}

variable "public_subnets" {
  description = "Public subnets for EFS mount targets"
  type        = map(object({
    id = string
  }))
}

variable "efs_security_group_id" {
  description = "Security group ID for EFS"
  type        = string
}

variable "install_package_path" {
  description = "Path to CSO installation package"
  type        = string
}

variable "setup_scripts_path" {
  description = "Path to setup scripts archive"
  type        = string
}
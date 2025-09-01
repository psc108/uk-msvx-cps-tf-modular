variable "environment" {
  description = "Environment name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instances"
  type        = string
}

variable "public_subnets" {
  description = "Public subnets"
  type        = list(object({
    id = string
  }))
}

variable "private_subnets" {
  description = "Private subnets"
  type        = list(object({
    id = string
  }))
}

variable "security_groups" {
  description = "Security groups"
  type        = object({
    jump_server = object({
      id = string
    })
    core_servers = object({
      id = string
    })
    external_web_access = object({
      id = string
    })
    inbound_web_access = object({
      id = string
    })
    efs = object({
      id = string
    })
  })
}



variable "root_ca_private_key" {
  description = "Root CA private key"
  type        = string
  sensitive   = true
}

variable "root_ca_cert" {
  description = "Root CA certificate"
  type        = string
}

variable "efs_mount_targets" {
  description = "EFS mount targets"
  type        = any
}

variable "prod" {
  description = "Production environment flag"
  type        = bool
}

variable "ha" {
  description = "High availability flag"
  type        = bool
}

variable "debug" {
  description = "Debug flag"
  type        = bool
}

variable "service_password" {
  description = "Service password"
  type        = string
  sensitive   = true
}

variable "keystone_password" {
  description = "Keystone password"
  type        = string
  sensitive   = true
}

variable "rabbitmq_password" {
  description = "RabbitMQ password"
  type        = string
  sensitive   = true
}

variable "key_password" {
  description = "Key password"
  type        = string
  sensitive   = true
}

variable "setup_scripts_path" {
  description = "Setup scripts path"
  type        = string
}

variable "install_package_path" {
  description = "Install package path"
  type        = string
}

# SSH-related variables removed - using SSM for access

variable "user_data_base" {
  description = "Base user data"
  type        = object({
    s3_bucket = string
  })
}

variable "private_zone_name" {
  description = "Private DNS zone name"
  type        = string
}

variable "mysql_hostname" {
  description = "MySQL hostname"
  type        = string
  default     = ""
}

variable "ssm_instance_profile" {
  description = "SSM instance profile"
  type        = object({
    name = string
  })
}

variable "frontend_target_group_arn" {
  description = "Frontend target group ARN for HA load balancer"
  type        = string
  default     = null
}

variable "efs_dns_name" {
  description = "EFS DNS name for mounting"
  type        = string
  default     = ""
}
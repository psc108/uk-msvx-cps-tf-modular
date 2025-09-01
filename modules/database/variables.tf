variable "environment" {
  description = "Environment name"
  type        = string
}

variable "private_subnets" {
  description = "Private subnets for RDS"
  type        = map(object({
    id = string
  }))
}

variable "core_servers_security_group_id" {
  description = "Security group ID for core servers"
  type        = string
}

variable "db_admin_user" {
  description = "Database admin username"
  type        = string
}



variable "prod" {
  description = "Production environment flag"
  type        = bool
  default     = false
}

variable "ha" {
  description = "High availability flag"
  type        = bool
  default     = false
}
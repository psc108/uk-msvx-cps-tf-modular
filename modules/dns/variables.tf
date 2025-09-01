variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_suffix" {
  description = "Domain suffix for DNS zone"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "db_endpoint" {
  description = "Database endpoint"
  type        = string
}

variable "ha" {
  description = "High availability flag"
  type        = bool
}

variable "frontend_instances" {
  description = "Frontend instances"
  type        = list(object({
    private_ip = string
  }))
}

variable "backend_instances" {
  description = "Backend instances"
  type        = list(object({
    private_ip = string
  }))
}

variable "keystone_instances" {
  description = "Keystone instances"
  type        = list(object({
    private_ip = string
  }))
}

variable "rabbitmq_instances" {
  description = "RabbitMQ instances"
  type        = list(object({
    private_ip = string
  }))
}
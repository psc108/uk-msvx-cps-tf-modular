variable "environment" {
  description = "Environment name"
  type        = string
}

variable "vpc_name" {
  description = "Name for the VPC"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "public_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "private_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
}

variable "azs" {
  description = "Availability zones"
  type        = map(string)
}

variable "ha" {
  description = "High availability deployment"
  type        = bool
  default     = false
}

variable "admin_email" {
  description = "Admin email for Cognito user creation"
  type        = string
  default     = "admin@company.com"
}

variable "admin_phone_number" {
  description = "Admin phone number for MFA (format: +1234567890)"
  type        = string
  default     = "+1234567890"
}

variable "backend_lb_certificate_arn" {
  description = "ARN of the backend load balancer certificate"
  type        = string
  default     = null
}
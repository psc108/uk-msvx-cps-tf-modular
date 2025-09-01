output "vpc_id" {
  description = "ID of the VPC"
  value       = aws_vpc.main.id
}

output "public_subnets" {
  description = "Public subnet resources"
  value       = aws_subnet.public
}

output "private_subnets" {
  description = "Private subnet resources"
  value       = aws_subnet.private
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = aws_internet_gateway.gw.id
}

output "frontend_load_balancer" {
  description = "Frontend load balancer"
  value       = var.ha ? aws_lb.frontend[0] : null
}

output "frontend_target_group" {
  description = "Frontend target group"
  value       = var.ha ? aws_lb_target_group.frontend[0] : null
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID"
  value       = var.ha ? aws_cognito_user_pool.main_v2[0].id : null
}

output "cognito_domain" {
  description = "Cognito Domain"
  value       = var.ha ? aws_cognito_user_pool_domain.main[0].domain : null
}

output "cognito_temp_password" {
  description = "Temporary password for Cognito admin user"
  value       = var.ha ? random_password.cognito_temp_password[0].result : null
  sensitive   = true
}
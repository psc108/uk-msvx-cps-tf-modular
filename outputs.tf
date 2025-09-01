output "jumpserver-ip" {
  value = module.compute.jump_server_eip.public_ip
}

output "ssm-session-cmd" {
  description = "Command to connect to jump server via SSM"
  value = "aws ssm start-session --target ${module.compute.jump_server.id}"
}

output "jump-server-instance-id" {
  description = "Jump server instance ID for SSM access"
  value = module.compute.jump_server.id
}

output "admin-ui-url" {
  value = local.env.ha ? (
    module.networking.frontend_load_balancer != null ? 
    "https://${module.networking.frontend_load_balancer.dns_name}/ui/management/login/system" : 
    "Load balancer not available"
  ) : (
    length(module.compute.frontend_eip) > 0 ? 
    "https://${module.compute.frontend_eip[0].public_dns}:8102/ui/management/login/system" : 
    "Frontend EIP not available"
  )
}

output "cognito_user_pool_id" {
  description = "Cognito User Pool ID for user management"
  value       = module.networking.cognito_user_pool_id
}

output "cognito_domain" {
  description = "Cognito authentication domain"
  value       = module.networking.cognito_domain
}

output "cognito_temp_password" {
  description = "Temporary password for Cognito admin user"
  value       = local.env.ha ? module.networking.cognito_temp_password : null
  sensitive   = true
}

output "s3_upload_summary" {
  description = "S3 files module bucket information"
  value = {
    bucket_name = module.s3_files.bucket_name
    bucket_arn  = module.s3_files.bucket_arn
  }
}

output "frontend-instance-ids" {
  description = "Frontend server instance IDs"
  value       = [for instance in module.compute.frontend_instances : instance.id]
}

output "backend-instance-ids" {
  description = "Backend server instance IDs"
  value       = [for instance in module.compute.backend_instances : instance.id]
}

output "keystone-instance-ids" {
  description = "Keystone server instance IDs"
  value       = [for instance in module.compute.keystone_instances : instance.id]
}

output "rabbitmq-instance-ids" {
  description = "RabbitMQ server instance IDs"
  value       = [for instance in module.compute.rabbitmq_instances : instance.id]
}

output "s3_bucket_name" {
  description = "S3 bucket name for file distribution"
  value       = module.s3_files.bucket_name
}

output "frontend_target_group_arn" {
  description = "Frontend target group ARN"
  value       = local.env.ha ? module.networking.frontend_target_group.arn : null
}
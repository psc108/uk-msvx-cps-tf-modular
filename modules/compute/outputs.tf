output "jump_server" {
  description = "Jump server instance"
  value       = aws_instance.jump-server
}

output "frontend_instances" {
  description = "Frontend server instances"
  value       = aws_instance.frontend
}

output "backend_instances" {
  description = "Backend server instances"
  value       = aws_instance.backend
}

output "rabbitmq_instances" {
  description = "RabbitMQ server instances"
  value       = aws_instance.rabbitmq
}

output "keystone_instances" {
  description = "Keystone server instances"
  value       = aws_instance.keystone
}

output "jump_server_eip" {
  description = "Jump server Elastic IP"
  value       = aws_eip.jump-server
}

output "frontend_server_eip" {
  description = "Frontend server Elastic IP (non-HA only)"
  value       = var.ha ? null : aws_eip.frontend-server[0]
}
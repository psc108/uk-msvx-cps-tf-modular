

output "root_ca_private_key" {
  description = "Root CA private key"
  value       = tls_private_key.root-ca
  sensitive   = true
}

output "root_ca_cert" {
  description = "Root CA certificate"
  value       = tls_self_signed_cert.root-ca
}

output "backend_lb_certificate" {
  description = "Backend load balancer certificate"
  value       = var.ha ? aws_acm_certificate.backend-lb[0] : null
}

output "ssm_instance_profile" {
  description = "SSM instance profile"
  value       = aws_iam_instance_profile.ssm_profile
}

output "patch_baseline" {
  description = "SSM patch baseline"
  value       = aws_ssm_patch_baseline.amazon_linux
}

output "maintenance_window" {
  description = "SSM maintenance window"
  value       = aws_ssm_maintenance_window.cso_patching
}

output "ssm_logs_bucket" {
  description = "S3 bucket for SSM logs"
  value       = aws_s3_bucket.ssm_logs
}

output "security_groups" {
  description = "Security groups"
  value = {
    jump_server           = aws_security_group.jump-server-sg
    core_servers         = aws_security_group.core-servers-sg
    external_web_access  = aws_security_group.external-web-access-sg
    inbound_web_access   = aws_security_group.inbound-web-access-sg
    efs                  = aws_security_group.efs
  }
}
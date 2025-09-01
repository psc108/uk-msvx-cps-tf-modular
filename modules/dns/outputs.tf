output "private_zone" {
  description = "Private DNS zone"
  value       = aws_route53_zone.private
}

output "dns_records" {
  description = "DNS records"
  value = {
    mysql    = aws_route53_record.mysql
    frontend = aws_route53_record.frontend
    backend  = aws_route53_record.backend
    keystone = aws_route53_record.keystone
    rabbitmq = aws_route53_record.rabbitmq
  }
}
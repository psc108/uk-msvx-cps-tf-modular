##### DNS Module - Route53 Records #####

resource "aws_route53_zone" "private" {
  name = "${var.environment}.${var.domain_suffix}"

  vpc {
    vpc_id = var.vpc_id
  }

  tags = {
    Environment = var.environment
  }
}

resource "aws_route53_record" "mysql" {
  zone_id = aws_route53_zone.private.zone_id
  name    = "mysql.${aws_route53_zone.private.name}"
  type    = "CNAME"
  ttl     = 300
  records = [var.db_endpoint]
}

resource "aws_route53_record" "frontend" {
  count   = length(var.frontend_instances)
  zone_id = aws_route53_zone.private.zone_id
  name    = "frontend0${count.index + 1}.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = [var.frontend_instances[count.index].private_ip]
}

resource "aws_route53_record" "backend" {
  count   = length(var.backend_instances)
  zone_id = aws_route53_zone.private.zone_id
  name    = "backend0${count.index + 1}.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = [var.backend_instances[count.index].private_ip]
}

resource "aws_route53_record" "keystone" {
  count   = length(var.keystone_instances)
  zone_id = aws_route53_zone.private.zone_id
  name    = "keystone0${count.index + 1}.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = [var.keystone_instances[count.index].private_ip]
}

resource "aws_route53_record" "rabbitmq" {
  count   = length(var.rabbitmq_instances)
  zone_id = aws_route53_zone.private.zone_id
  name    = "rabbitmq0${count.index + 1}.${aws_route53_zone.private.name}"
  type    = "A"
  ttl     = 300
  records = [var.rabbitmq_instances[count.index].private_ip]
}
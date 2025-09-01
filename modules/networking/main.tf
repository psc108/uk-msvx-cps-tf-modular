##### VPC and Networking Module #####

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  instance_tenancy     = "default"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "${var.environment}-${var.vpc_name}"
    Environment = var.environment
  }
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  
  tags = {
    Name        = "${var.environment}-${var.vpc_name}-igw"
    Environment = var.environment
  }
}

##### Subnets #####
resource "aws_subnet" "public" {
  for_each          = var.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.public_cidrs[each.key]
  availability_zone = each.value

  tags = {
    Name        = "${var.environment}-public-0${each.key + 1}-subnet"
    Environment = var.environment
  }
}

resource "aws_subnet" "private" {
  for_each          = var.azs
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_cidrs[each.key]
  availability_zone = each.value

  tags = {
    Name        = "${var.environment}-private-0${each.key + 1}-subnet"
    Environment = var.environment
  }
}

##### Route Tables #####
resource "aws_default_route_table" "default" {
  default_route_table_id = aws_vpc.main.default_route_table_id
  tags = {
    Name        = "${var.environment}-default-routes"
    Environment = var.environment
  }
}

resource "aws_route_table" "private" {
  for_each = aws_subnet.private
  vpc_id   = aws_vpc.main.id
  
  tags = {
    Name        = "${var.environment}-private-0${each.key + 1}-routes"
    Environment = var.environment
  }
}

resource "aws_route_table" "public" {
  for_each = aws_subnet.public
  vpc_id   = aws_vpc.main.id
  
  tags = {
    Name        = "${var.environment}-public-0${each.key + 1}-routes"
    Environment = var.environment
  }
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private[each.key].id
}

resource "aws_route_table_association" "public" {
  for_each       = aws_subnet.public
  subnet_id      = each.value.id
  route_table_id = aws_route_table.public[each.key].id
}

##### NAT Gateway #####
resource "aws_eip" "nat-gw" {
  count  = var.ha ? 2 : 1
  domain = "vpc"

  tags = {
    Name        = "${var.environment}-private-subnet-0${count.index + 1}-nat-eip"
    Environment = var.environment
  }
}

resource "aws_nat_gateway" "main" {
  count         = var.ha ? 2 : 1
  allocation_id = aws_eip.nat-gw[count.index].id
  subnet_id     = values(aws_subnet.public)[count.index].id

  tags = {
    Name        = "${var.environment}-private-subnet-0${count.index + 1}-nat"
    Environment = var.environment
  }

  depends_on = [aws_internet_gateway.gw]
}

resource "aws_route" "natgw-default-route" {
  for_each               = aws_route_table.private
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.ha ? aws_nat_gateway.main[each.key].id : aws_nat_gateway.main[0].id
}

resource "aws_route" "igw-default-route" {
  for_each               = aws_route_table.public
  route_table_id         = each.value.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.gw.id
}

##### Load Balancers #####
resource "aws_lb" "frontend" {
  count              = var.ha ? 1 : 0
  name               = "${var.environment}-frontend-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.frontend_lb[count.index].id]
  subnets            = [for subnet in aws_subnet.public : subnet.id]

  enable_deletion_protection = false # set to this var.ha when testing is done
  enable_cross_zone_load_balancing = true

  tags = {
    Name        = "${var.environment}-frontend-lb"
    Environment = var.environment
  }
}

resource "aws_security_group" "frontend_lb" {
  count       = var.ha ? 1 : 0
  name        = "${var.environment}-frontend-lb-sg"
  description = "Security group for frontend load balancer"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8102
    to_port     = 8102
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "${var.environment}-frontend-lb-sg"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "frontend" {
  count    = var.ha ? 1 : 0
  name     = "${var.environment}-frontend-tg"
  port     = 8102
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 30
    matcher             = "200"
    path                = "/ui/management/login/system"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    unhealthy_threshold = 3

  }

  tags = {
    Name        = "${var.environment}-frontend-tg"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "frontend" {
  count             = var.ha ? 1 : 0
  load_balancer_arn = aws_lb.frontend[0].arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = var.backend_lb_certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend[count.index].arn
  }
}
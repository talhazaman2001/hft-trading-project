# VPC
resource "aws_vpc" "main_vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "main-vpc"
    }
}

# Identify the CIDR ranges for the 3 Public Subnets
variable "public_subnet_cidrs" {
    type = list(string)
    description = "Public Subnet CIDR Values"
    default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

# Identify the CIDR Ranges for the 3 Private Subnets
variable "private_subnet_cidrs" {
    type = list(string)
    description = "Private Subnet CIDR Values"
    default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}

# Store the list of Availability Zones
variable "azs" {
    type = list(string)
    description = "Availability Zones"
    default = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

# Public Subnets
resource "aws_subnet" "public_subnets" {
    count = length(var.public_subnet_cidrs)
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = element(var.public_subnet_cidrs, count.index)
    availability_zone = element(var.azs, count.index)
}

# Private Subnets
resource "aws_subnet" "private_subnets" {
    count = length(var.private_subnet_cidrs)
    vpc_id = aws_vpc.main_vpc.id
    cidr_block = element(var.public_subnet_cidrs, count.index)
    availability_zone = element(var.azs, count.index)
}

# IGW for Public Subnets
resource "aws_internet_gateway" "igw" {
    vpc_id = aws_vpc.main_vpc.id
}

# Route Table for Public Subnets
resource "aws_route_table" "public_rt" {
    vpc_id = aws_vpc.main_vpc.id
}

# Associate Route Table with Public Subnet
resource "aws_route_table_associaton" "public_rt_assoc" {
    count = 3
    subnet_id = aws_subnet.public_subnets[count.index].id
    route_table_id = aws_route_table.public_rt.id
}

# Add Route to Public Route Table (internet access)
resource "aws_route" "public_route" {
    route_table_id = aws_route_table.public_rt.id
    destination_cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
}

# Elastic IPs for NAT Gateway
resource "aws_eip" "nat_eip" {
count = 3  
}

# NAT Gateways for Private Subnets
resource "aws_nat_gateway" "nat_gateway" {
    count = 3
    allocation_id = aws_eip.nat_eip[count.index].id
    subnet_id = aws_subnet.public_subnets[count.index].id 
}

# Route Table for Private Subnets (use NAT Gateway)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
}

# Associate Route Table with Private Subnets
resource "aws_route_table_association" "private_rt-assoc" {
  count          = 3
  subnet_id      = aws_subnet.private_subnets[count.index].id
  route_table_id = aws_route_table.private_rt.id
}


# Add Route to Private Route Table
resource "aws_route" "private_route" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gateway[0].id
}

# Application Load Balancer in Public Subnets
resource "aws_lb" "ecs_alb" {
  name               = "ecs-application-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public_subnets[*].id

  enable_deletion_protection = false

  tags = {
    Name = "ecs-application-load-balancer"
  }
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name   = "hft-lb-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Define the Target Groups for Blue and Green Deployment
resource "aws_lb_target_group" "trade_signal_processor_blue_tg" {
    name = "trade-signal-processor-blue-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

resource "aws_lb_target_group" "trade_signal_processor_green_tg" {
    name = "trade-signal-processor-green-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

resource "aws_lb_target_group" "market_data_ingestor_blue_tg" {
    name = "market-data-ingestor-blue-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

resource "aws_lb_target_group" "market_data_ingestor_green_tg" {
    name = "market-data-ingestor-green-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

resource "aws_lb_target_group" "risk_management_service_blue_tg" {
    name = "risk-management-service-blue-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

resource "aws_lb_target_group" "risk_management_service_green_tg" {
    name = "risk-management-service-green-tg"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "ip"
    health_check {
      path = "/health"
    }
}

# Define the listener for market data
resource "aws_lb_listener" "ecs_listener" {
    load_balancer_arn = aws_lb.my_alb.arn  
    port = 80                 
    protocol = "HTTP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.market_data_ingestor_blue_tg
    }
}

# Listener Rule for Trade Signal Processor
resource "aws_lb_listener_rule" "trade_signal_processor_rule" {
  listener_arn = aws_lb_listener.ecs_listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.trade_signal_processor_blue_tg.arn
  }

  condition {
    path_pattern {
      values = ["/trade-signal-processor/*"]
    }
  }
}

# Listener Rule for Market Data Ingestor
resource "aws_lb_listener_rule" "market_data_ingestor_rule" {
  listener_arn = aws_lb_listener.ecs_listener.arn
  priority     = 2

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.market_data_ingestor_blue_tg.arn
  }

  condition {
    path_pattern {
      values = ["/market-data-ingestor/*"]
    }
  }
}

# Listener Rule for Risk Management Service
resource "aws_lb_listener_rule" "risk_management_service_rule" {
  listener_arn = aws_lb_listener.ecs_listener.arn
  priority     = 3

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.risk_management_service_blue_tg.arn
  }

  condition {
    path_pattern {
      values = ["/risk-management-service/*"]
    }
  }
}




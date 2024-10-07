# Define the ECS cluster
resource "aws_ecs_cluster" "hft_cluster" {
    name = "hft-cluster"
}

# IAM Role for ECS Task Execution
resource "aws_iam_role" "ecs_task_execution_role" {
    
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [{
            Action = "sts:AssumeRole"
            Effect = "Allow"
            Principal = {
                Service = "ecs-tasks.amazonaws.com"
            }
        }]
    })
}

# Attach ECS Task Policy to IAM Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# Attach X-Ray Policy to write to ECS
resource "aws_iam_role_policy_attachment" "ecs_task_xray_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Attach CloudWatch Policy to log ECS
resource "aws_iam_role_policy_attachment" "ecs_task_cloudwatch_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess"
}

# Attach DynamoDB Policy to read from ECS
resource "aws_iam_role_policy_attachment" "ecs_task_dynamodb_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}

# Attach S3 Policy to allow ECS microservices to store and retrieve data 
resource "aws_iam_policy" "ecs_task_s3_policy" {
    name = "ecs-s3-least-privilege"
    
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:GetObject",
                    "s3:PutObject"
                ]
                Resource = "arn:aws:s3:::your-bucket-name/*" # reference bucket once created 
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_s3_policy_attach" {
    role = aws_iam_role.ecs_task_execution_role.name
    policy_arn = aws_iam_policy.ecs_task_s3_policy.arn
}

# Attach Kinesis Policy to ECS
resource "aws_iam_policy" "ecs_task_kinesis_policy" {
    name = "ecs-kinesis-least-privilege"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "kinesis:PutRecord",
                    "kinesis:GetRecords",
                    "kinesis:DescribeStream",
                    "kinesis:GetShardIterator"
                ]
                Resource = "${aws_kinesis_stream.market_data_stream.arn}"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_kinesis_policy_attach" {
    role = aws_iam_role.ecs_task_execution_role.name
    policy_arn = aws_iam_policy.ecs_task_kinesis_policy.arn
}

# Attach Aurora RDS policy to ECS
resource "aws_iam_policy" "ecs_task_aurora_policy" {
    name = "ecs-aurora-least-privilege"
    
    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "rds-data:ExecuteStatement",
                    "rds-data:BatchExecuteStatement"
                ]
                Resource = "${aws_rds_cluster.aurora_cluster.arn}" 
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "ecs_task_aurora_policy_attach" {
    role = aws_iam_role.ecs_task_execution_role.name
    policy_arn = aws_iam_policy.ecs_task_aurora_policy.arn
}

# ECS Task Definition for Dockerised Microservices
resource "aws_ecs_task_definition" "hft_task" {
    family = "hft-task"
    execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
    task_role_arn = aws_iam_role.ecs_task_execution_role.arn
    network_mode = "awsvpc"
    requires_compatibilities = ["EC2"]
    cpu = "1024"
    memory = "2048"

    container_definitions = jsonencode([
        {
            name = "trade-signal-processing"
            image = "${aws_ecr_repository.trade_signal_processing.repository_url}:latest"
            essential = true 
            cpu = 256
            memory = 512
            portMappings = [
                {
                    containerPort = 5000
                    hostPort = 5000
                }
            ],
            environment = [
                {
                    name = "DYNAMODB_TABLE"
                    value = "trade_signals"
                }
            ]
        },
        {
            name = "market-data-ingestion"
            image = "${aws_ecr_repository.market_data_ingestion.repository_url}:latest"
            essential = true 
            cpu = 256
            memory = 512
            portMappings = [
                {
                    containerPort = 8080
                    hostPort = 8080
                }
            ],
            environment = [
                {
                    name = "KINESIS_STREAM"
                    value = "market_data_stream"
                }
            ]
        },
        {
            name = "risk-management-service"
            image = "${aws_ecr_repository.risk_management_service.repository_url}:latest"
            essential = true 
            cpu = 256
            memory = 512
            portMappings = [
                {
                    containerPort = 6000
                    hostPort = 6000
                }
            ],
            environment = [
                {
                    name = "AURORA_DB_HOST"
                    value = "my-aurora-endpoint"
                },
                {
                    name = "AURORA_DB_USER"
                    value = "my-aurora-user"
                },
                {
                    name = "AURORA_DB_PASSWORD"
                    value = "my-aurora-password"
                },
                {
                    name = "AURORA_DB_NAME"
                    value = "risk_management"
                }
            ]
        }
    ])
}

# ECS Security Group
resource "aws_security_group" "ecs_sg" {
    vpc_id = aws_vpc.main_vpc.id
    name = "ecs-service-sg"

    ingress {
        from_port = 5000
        to_port = 5000
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    ingress {
        from_port = 8080
        to_port = 8080
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    ingress {
        from_port = 6000
        to_port = 6000
        protocol = "tcp"
        security_groups = [aws_security_group.alb_sg.id]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Define the 3 ECS services
resource "aws_ecs_service" "trade_signal_processing" {
    name = "trade-signal-processing"
    cluster = aws_ecs_cluster.hft_cluster.id
    task_definition = aws_ecs_task_definition.hft_task.arn
    launch_type = "EC2"
    desired_count = 1

    deployment_controller {
      type = "CODE_DEPLOY"
    }

    load_balancer {
      target_group_arn = aws_lb_target_group.trade_signal_processing_blue_tg.arn
      container_name = "trade-signal-processing"
      container_port = 5000
    }

    network_configuration {
      subnets = aws_subnet.private_subnets[*].id
      security_groups = [aws_security_group.ecs_sg.id]
      assign_public_ip = false 
    }
}

resource "aws_ecs_service" "market_data_ingestion" {
    name = "market-data-ingestion"
    cluster = aws_ecs_cluster.hft_cluster.id
    task_definition = aws_ecs_task_definition.hft_task.arn
    launch_type = "EC2"
    desired_count = 1

    deployment_controller {
      type = "CODE_DEPLOY"
    }

    load_balancer {
      target_group_arn = aws_lb_target_group.market_data_ingestion_blue_tg.arn
      container_name = "market-data-ingestion"
      container_port = 8080
    }

    network_configuration {
      subnets = aws_subnet.private_subnets[*].id
      security_groups = [aws_security_group.ecs_sg.id]
      assign_public_ip = false 
    }
}

resource "aws_ecs_service" "risk_management_service" {
    name = "risk-management-service"
    cluster = aws_ecs_cluster.hft_cluster.id
    task_definition = aws_ecs_task_definition.hft_task.arn
    launch_type = "EC2"
    desired_count = 1

    deployment_controller {
      type = "CODE_DEPLOY"
    }

    load_balancer {
      target_group_arn = aws_lb_target_group.risk_management_service_blue_tg.arn
      container_name = "risk-management-service"
      container_port = 6000
    }

    network_configuration {
      subnets = aws_subnet.private_subnets[*].id
      security_groups = [aws_security_group.ecs_sg.id]
      assign_public_ip = false 
    }
}



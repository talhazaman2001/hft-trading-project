# Aurora RDS Cluster
resource "aws_rds_cluster" "aurora_cluster" {
    cluster_identifier = "auror-cluster"
    engine = "aurora-mysql"
    engine_version = "8.0"
    master_username = "admin"
    master_password = "password"
    backup_retention_period = 7
    preferred_backup_window = "07:00-09:00"
    database_name = "hftdb"
    iam_database_authentication_enabled = true 

    db_subnet_group_name = aws_db_subnet_group.aurora_subnet_group.name

    vpc_security_group_ids = [aws_security_group.aurora_sg.id]
}

# Define Aurora DB Instanecs
resource "aws_rds_cluster_instance" "aurora_instance" {
    count = 2
    identifier = "aurora-instance-${count.index}"
    cluster_identifier = aws_rds_cluster.aurora_cluster.id
    instance_class = "db.r5.large"
    engine = aws_rds_cluster.aurora_cluster.engine
}

# Subnet Group for Aurora Cluster
resource "aws_db_subnet_group" "aurora_subnet_group" {
    name = "aurora-subnet-group-talha"
    subnet_ids = aws_subnet.private_subnets[*].id
}

# Security Group for Aurora
resource "aws_security_group" "aurora_sg" {
    name = "aurora-sg"
    description = "Allow access to Aurora from ECS"
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        from_port = 3306
        to_port = 3306
        protocol = "tcp"
        cidr_blocks = ["10.0.0.0/16"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# DynamoDB Trade Signal Table
resource "aws_dynamodb_table" "dynamodb_trade_signal_table" {
    name = "TradeSignals"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "TradeID"
    range_key = "Timestamp"

    attribute {
      name = "TradeID"
      type = "S"
    }

    attribute {
      name = "Timestamp"
      type = "N"
    }

    global_secondary_index {
      name = "SymbolIndex"
      hash_key = "Symbol"
      projection_type = "ALL"
    }

    attribute {
      name = "Symbol"
      type = "S"
    }
}

# DynamoDB Market Data Ingestor Table
resource "aws_dynamodb_table" "dynamodb_market_data_table" {
    name = "MarketData"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "Symbol"
    range_key = "Timestamp"

    attribute {
      name = "Symbol"
      type = "S"
    }

    attribute {
      name = "Timestamp"
      type = "N"
    }

    attribute {
      name = "Price"
      type = "N"
    }

    attribute {
      name = "Volume"
      type = "N"
    }

    global_secondary_index {
      name = "PriceIndex"
      hash_key = "Price"
      projection_type = "ALL"
    }

    global_secondary_index {
      name = "VolumeIndex"
      hash_key = "Volume"
      projection_type = "ALL"
    }
}


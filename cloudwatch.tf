# ECS CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_log_group" {
    name = "/ecs/hft-application"
    retention_in_days = 30
}

# ECS CPU Utilisation Alarm
resource "aws_cloudwatch_metric_alarm" "ecs_high_cpu_alarm" {
    alarm_name = "ecs-high-cpu-alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilisation"
    namespace = "AWS/ECS"
    period = 300
    statistic = "Average"
    threshold = 80 # Trigger alarm at 80% CPU Utilisation
    alarm_actions = [var.ecs_alarm_action]
    dimensions = {
        ClusterName = "hft-cluster"
    }
}

# SNS Topic for ECS CloudWatch Alarm
resource "aws_sns_topic" "ecs_alarm_sns_topic" {
    name = "ecs-alarms-topic"
}

resource "aws_sns_topic_subscription" "ecs_alarm_subscription" {
    topic_arn = aws_sns_topic.ecs_alarm_sns_topic.arn
    protocol = "email"
    endpoint = "mtalhazamanb@gmail.com"
}

variable "ecs_alarm_action" {
    default = aws_sns_topic.ecs_alarm_sns_topic.arn
}

# EC2 CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ec2_log_group" {
    name = "/ec2/hft-application"
    retention_in_days = 30
}

# Fetch the EC2 Instance IDs created by Auto Scaling Group
data "aws_instances" "asg_instances" {
    filter {
        name = "tag:aws:autoscaling:groupName"
        values = [aws_autoscaling_group.blue_asg.name]
    }
}
# EC2 CPU Utilisation Alarm
resource "aws_cloudwatch_metric_alarm" "ec2_high_cpu_alarm" {
    alarm_name = "ec2-high-cpu-alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilisation"
    namespace = "AWS/EC2"
    period = 300
    statistic = "Average"
    threshold = 80 # Trigger alarm at 80% CPU Utilisation
    alarm_actions = [var.ec2_alarm_action]
    dimensions = {
        InstanceId = data.aws_instances.asg_instances.ids[count.index]
    }
}

# SNS Topic for EC2 CloudWatch Alarm
resource "aws_sns_topic" "ec2_alarm_sns_topic" {
    name = "ec2-alarms-topic"
}

resource "aws_sns_topic_subscription" "ec2_alarm_subscription" {
    topic_arn = aws_sns_topic.ec2_alarm_sns_topic.arn
    protocol = "email"
    endpoint = "mtalhazamanb@gmail.com"
}

variable "ec2_alarm_action" {
    default = aws_sns_topic.ec2_alarm_sns_topic.arn
}


# SageMaker CloudWatch Log Group
resource "aws_cloudwatch_log_group" "sagemaker_log_group" {
    name = "/sagemaker/hft-application"
    retention_in_days = 30
}

# SageMaker Inference Error Alarm
resource "aws_cloudwatch_metric_alarm" "sagemaker_inference_error_alarm" {
    alarm_name = "sagemaker-inference-error-alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 1
    metric_name = "ModelLatency"
    namespace = "AWS/SageMaker"
    period = 3600
    statistic = "Average"
    threshold = 1000 # Trigger alarm if inference latency exceeds 1000ms
    alarm_actions = [var.sagemaker_alarm_action]
    dimensions = {
        EndpointName = aws_sagemaker_endpoint.hft_endpoint.endpoint_name
    }
}

# SNS Topic for SageMaker CloudWatch Alarm
resource "aws_sns_topic" "sagemaker_alarm_sns_topic" {
    name = "sagemaker-alarms-topic"
}

resource "aws_sns_topic_subscription" "sagemaker_alarm_subscription" {
    topic_arn = aws_sns_topic.sagemaker_alarm_sns_topic.arn
    protocol = "email"
    endpoint = "mtalhazamanb@gmail.com"
}

variable "sagemaker_alarm_action" {
    default = aws_sns_topic.sagemaker_alarm_sns_topic.arn
}

# Kinesis CloudWatch Log Group
resource "aws_cloudwatch_log_group" "kinesis_log_group" {
    name = "/kinesis/hft-market-data"
    retention_in_days = 30
}

# Kinesis Data Stream Incoming Data Alarm
resource "aws_cloudwatch_metric_alarm" "kinesis_incoming_data_alarm" {
    alarm_name = "kinesis-incoming-data-alarm"
    comparison_operator = "LessThanThreshold"
    evaluation_periods = 2
    metric_name = "IncomingBytes"
    namespace = "AWS/Kinesis"
    period = 300
    statistic = "Average"
    threshold = 100000 # Trigger alarm if incoming data is below 100KB
    alarm_actions = [var.kinesis_alarm_action]
    dimensions = {
        StreamName = aws_kinesis_stream.market_data_stream.name
    }
}

# SNS Topic for Kinesis CloudWatch Alarm
resource "aws_sns_topic" "kinesis_alarm_sns_topic" {
    name = "kinesis-alarms-topic"
}

resource "aws_sns_topic_subscription" "kinesis_alarm_subscription" {
    topic_arn = aws_sns_topic.kinesis_alarm_sns_topic.arn
    protocol = "email"
    endpoint = "mtalhazamanb@gmail.com"
}

variable "kinesis_alarm_action" {
    default = aws_sns_topic.kinesis_alarm_sns_topic.arn
}

# Aurora CloudWatch Log Group
resource "aws_cloudwatch_log_group" "aurora_log_group" {
    name = "/aurora/hft-market-data"
    retention_in_days = 30
}

# Aurora DB Connections Alarm
resource "aws_cloudwatch_metric_alarm" "aurora_db_connections_alarm" {
    alarm_name = "aurora-db-connections-alarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "DatabaseConnections"
    namespace = "AWS/RDS"
    period = 300
    statistic = "Average"
    threshold = 100 # Trigger alarm if connections exceed 100
    alarm_actions = [var.aurora_alarm_action]
    dimensions = {
        DBClusterIdentifier = aws_rds_cluster.aurora_cluster.id
    }
}

# SNS Topic for Aurora CloudWatch Alarm
resource "aws_sns_topic" "Aurora_alarm_sns_topic" {
    name = "aurora-alarms-topic"
}

resource "aws_sns_topic_subscription" "aurora_alarm_subscription" {
    topic_arn = aws_sns_topic.aurora_alarm_sns_topic.arn
    protocol = "email"
    endpoint = "mtalhazamanb@gmail.com"
}

variable "aurora_alarm_action" {
    default = aws_sns_topic.aurora_alarm_sns_topic.arn
}
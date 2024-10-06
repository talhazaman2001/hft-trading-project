# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
    name = "hft-ec2-s3-directconnect-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "ec2.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# IAM Policy for S3 Access and Direct Connect Permissions
resource "aws_iam_policy" "ec2_policy" {
    name = "hft-ec2-s3-directconnect-policy"

    policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Action = [
                    "s3:PutObject",
                    "s3:GetObject",
                    "s3:ListBucket",
                    "directconnect:DescribeConnection",
                    "directconnect:DescribeDirectConnectGateway"
                ],
                Resource = [
                    "arn:aws:s3:::my-hft-s3-bucket",
                    "arn:aws:s3:::my-hft-s3-bucket/*"
                ]
            }
        ]
    })
}

# Attach Policy to Role
resource "aws_iam_role_policy_attachment" "ec2_policy_attachment" {
    role = aws_iam_role.ec2_role.name
    policy_arn = aws_iam_policy.ec2_policy.arn
}

resource "aws_iam_role_policy_attachment" "ec2_xray_policy" {
    role = aws_iam_role.ec2_role.name
    policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Create the IAM instance profile for the EC2 instances
resource "aws_iam_instance_profile" "ec2_instance_profile" {
    name = "hft-ec2-instance-profile"
    role = aws_iam_role.ec2_role.name
}

# Network Load Balancer
resource "aws_lb" "nlb" {
    name = "hft-nlb"
    internal = false 
    load_balancer_type = "network"
    subnets = aws_subnet.public_subnets[*].id
}

# EC2 Target Groups for Blue-Green Deployment
resource "aws_lb_target_group" "ec2_blue_target_group" {
    name = "ec2-blue-target-group"
    port = 80
    protocol = "TCP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "instance"
}

resource "aws_lb_target_group" "ec2_green_target_group" {
    name = "ec2-green-target-group"
    port = 80
    protocol = "TCP"
    vpc_id = aws_vpc.main_vpc.id
    target_type = "instance"
}
  
# Define NLB listener
resource "aws_lb_listener" "nlb_listener" {
    load_balancer_arn = aws_lb.nlb.arn
    port = 80
    protocol = "TCP"

    default_action {
      type = "forward"
      target_group_arn = aws_lb_target_group.ec2_blue_target_group.arn
    }
}

# EC2 Launch Template
resource "aws_launch_template" "ec2_launch_template" {
    name = "hft-ec2-launch-template"

    iam_instance_profile {
      name = aws_iam_instance_profile.ec2_instance_profile.name
    }

    image_id = data.aws_ami.ubuntu.id
    instance_type = "c5n.large"
    user_data = base64encode(<<EOF
    #!bin/bash
    echo "Fetching data from on-prem servers via Direct Connect"
    echo "processing and storing data in S3"
    aws s3 cp /path/to/data s3://my-hft-s3-bucket/data --recursive

    # Install X-Ray Daemon
    apt-get update -y
    apt-get install -y aws-xray-daemon

    systemctl start xray
    systemctl enable xray
    EOF
    )
    vpc_security_group_ids = [aws_security_group.ec2_sg.id]
}

# Blue Environment Auto Scaling Group
resource "aws_autoscaling_group" "blue_asg" {
    desired_capacity = 2
    max_size = 4
    min_size = 1
    vpc_zone_identifier = aws_subnet.private_subnets[*].id

    launch_template {
      id = aws_launch_template.ec2_launch_template.id
      version = "$Latest"
    }

    target_group_arns = [aws_lb_target_group.ec2_blue_target_group.arn]
}

# Green Environment Auto Scaling Group
resource "aws_autoscaling_group" "green_asg" {
    desired_capacity = 2
    max_size = 4
    min_size = 1
    vpc_zone_identifier = aws_subnet.private_subnets[*].id

    launch_template {
      id = aws_launch_template.ec2_launch_template.id
      version = "$Latest"
    }

    target_group_arns = [aws_lb_target_group.ec2_green_target_group.arn]
}

# Security Groups for EC2 Instances
resource "aws_security_group" "ec2_sg" {
    name = "hft-ec2-sg"
    description = "Allow NLB traffic to EC2 instances"
    vpc_id = aws_vpc.main_vpc.id

    ingress {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}

# Auto Scaling Schedule
resource "aws_autoscaling_schedule" "pre_provision_scale_up" {
    autoscaling_group_name = aws_autoscaling_group.blue_asg.name
    scheduled_action_name = "PreProvisionScaleUp"
    recurrence = "0 8 ** 1-5" # Scale up at 8AM on weekdays for market open
    desired_capacity = 5
    min_size = 5
    max_size = 10
}

resource "aws_autoscaling_schedule" "pre_provision_scale_down" {
    autoscaling_group_name = aws_autoscaling_group.blue_asg.name
    scheduled_action_name = "PreProvisionScaleDown"
    recurrence = "0 16 ** 1-5" # Scale down after 4PM on weekdays for market close
    desired_capacity = 2
    min_size = 2
    max_size = 5
}

# Auto Scaling Policies for Scaling Up and Down with CloudWatch Alarms
resource "aws_autoscaling_policy" "custom_metric_scale_up" {
    name = "ScaleUpCustomMetric"
    scaling_adjustment = 1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.blue_asg.name

    metric_aggregation_type = "Average"
    estimated_instance_warmup = 120

    policy_type = "SimpleScaling"
}

resource "aws_cloudwatch_metric_alarm" "scale_up_on_latency" {
    alarm_name = "HighLatencyAlarm"
    comparison_operator = "GreaterThanThreshold"
    evaluation_periods = 2
    metric_name = "Latency"
    namespace = "HFT/Performance"
    period = 60
    statistic = "Average"
    threshold = 100
    alarm_actions = [aws_autoscaling_policy.custom_metric_scale_up.arn]
    dimensions = {
      AutoScalingGroupName = aws_autoscaling_group.blue_asg.name
    }
}

resource "aws_autoscaling_policy" "custom_metric_scale_down" {
    name = "ScaleDownCustomMetric"
    scaling_adjustment = -1
    adjustment_type = "ChangeInCapacity"
    cooldown = 300
    autoscaling_group_name = aws_autoscaling_group.blue_asg.name

    metric_aggregation_type = "Average"
    estimated_instance_warmup = 120

    policy_type = "SimpleScaling"
} 

resource "aws_cloudwatch_metric_alarm" "scale_down_on_low_throughput" {
    alarm_name = "LowThroughputAlarm"
    comparison_operator = "LowerThanThreshold"
    evaluation_periods = 2
    metric_name = "NetworkPacketsIn"
    namespace = "AWS/EC2"
    period = 60
    statistic = "Sum"
    threshold = 500000
    alarm_actions = [aws_autoscaling_policy.custom_metric_scale_down.arn]
    dimensions = {
      AutoScalingGroupName = aws_autoscaling_group.blue_asg.name
    }
}

# Predictive Auto Scaling Policy
resource "aws_autoscaling_policy" "predictive_scaling_policy" {
    name = "PredictiveScalingPolicy"
    policy_type = "PredictiveScaling"
    autoscaling_group_name = aws_autoscaling_group.blue_asg.name

    predictive_scaling_configuration {
      metric_specification {
        target_value = 70
        predefined_metric_pair_specification {
          predefined_metric_type = "ASGAverageCPUUtilisation"
        }
      }
      mode = "ForecastOnly"
      scheduling_buffer_time = 300
    }
}


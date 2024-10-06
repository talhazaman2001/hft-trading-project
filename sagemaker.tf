# IAM Roles for DynamoDB, CloudWatch, S3, Kinesis and ECS
resource "aws_iam_role" "sagemaker_execution_role" {
    name = "sagemaker-execution-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "sagemaker.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# IAM Policy for Sagemaker to read from DynamoDB
resource "aws_iam_policy" "sagemaker_dynamodb_policy" {
  name = "sagemaker-rds-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "dynamodb:GetItem",
          "dynamodb:Scan",
          "dynamodb:Query"
        ],
        Resource = "${aws_dynamodb_table.dynamodb_market_data_table.arn}"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_dynamodb_policy_attach" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = aws_iam_policy.sagemaker_dynamodb_policy.arn
}

resource "aws_iam_role_policy_attachment" "sagemaker_cloudwatch_logging" {
  role = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLogsFullAccess" 
}

# IAM Policy for Sagemaker to access S3 Bucket to read datasets, write model artifacts, and retrieve training results
resource "aws_iam_policy" "sagemaker_execution_s3_access_policy" {
  name = "sagemaker-s3-access-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket"
        ],
        Resource = [
          "arn:aws:s3:::${aws_s3_bucket.sagemaker_bucket.bucket}/*", # Access objects
          "arn:aws:s3:::${aws_s3_bucket.sagemaker_bucket.bucket}"    # List bucket
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sagemaker_policy_attach" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = aws_iam_policy.sagemaker_execution_s3_access_policy.arn
}

# Create SageMaker Notebook Instance

resource "aws_sagemaker_notebook_instance" "hft_notebook" {
    name = "hft-notebook-instance"
    instance_type = "ml.t2.medium"  
    role_arn = aws_iam_role.sagemaker_execution_role.arn
    lifecycle_config_name = aws_sagemaker_notebook_instance_lifecycle_config.hft_notebook_lifecycle.name

    tags = {
        Name = "HFT-SageMaker-Notebook"
    }
}

# IAM Role for SageMaker Notebook
resource "aws_iam_role" "sagemaker_execution_role" {
    name = "sagemaker-execution-role"
    
    assume_role_policy = jsonencode({
        Version = "2012-10-17"
        Statement = [
            {
                Effect = "Allow"
                Principal = {
                    Service = "sagemaker.amazonaws.com"
                    },
                    Action = "sts:AssumeRole"
            }
        ]
    })
}

# Attach necessary policies to the IAM Role
resource "aws_iam_role_policy_attachment" "sagemaker_full_access" {
  role       = aws_iam_role.sagemaker_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSageMakerFullAccess"
}

resource "aws_iam_role_policy_attachment" "sagemaker_xray_policy" {
    role = aws_iam_role.sagemaker_execution_role.arn
    policy_arn = "arn:aws:iam::aws:policy/AmazonXRayDaemonWriteAccess"
}

# SageMaker Notebook Instance Lifecycle Configuration
resource "aws_sagemaker_notebook_instance_lifecycle_configuration" "hft_notebook_lifecycle" {
    name = "hft-notebook-lifecycle"

    on_start = <<EOF
#!/bin/bash
sudo -u ec2-user -i <<'EOF2'
pip install --upgrade boto3
pip install numpy pandas scikit-learn
EOF2
EOF

    on_create = <<EOF
#!/bin/basj
sudo -u ec2-user -i <<'EOF2'

echo "Notebook instance created"
EOF2
EOF
}

# Create the SageMaker model
resource "aws_sagemaker_model" "hft_model" {
    name = "hft-trained-model"
    execution_role_arn = aws_iam_role.sagemaker_execution_role.arn

    primary_container {
      image = "xgboost:latest"
      model_data_url = "s3://${aws_s3_bucket.sagemaker_bucket.bucket}/training-data-and-artifacts/model.tar.gz"
    }
}

# Create the SageMaker Endpoint Configuration
resource "aws_sagemaker_endpoint_configuration" "hft_endpoint_config" {
    name = "hft-endpoint-config"
    
    production_variants {
      variant_name = "primary-variant"
      model_name = aws_sagemaker_model.hft_model.name
      initial_instance_count = 1
      instance_type = "ml.m5.large"
    }
}

# Create the SageMaker Endpoint
resource "aws_sagemaker_endpoint" "hft_endpoint" {
    endpoint_config_name = aws_sagemaker_endpoint_configuration.hft_endpoint_config.name
    name = "hft-inference-endpoint"
}
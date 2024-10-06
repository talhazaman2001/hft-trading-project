# S3 Bucket for ECS and EC2
resource "aws_s3_bucket" "ecs_ec2_bucket" {
    bucket = "ecs-ec2-bucket-talha"
}

# Lifecycle Rule for ECS and EC2 Bucket
resource "aws_s3_bucket_lifecycle_configuration" "ecs_ec2_config" {
    bucket = aws_s3_bucket.ecs_ec2_bucket.id

    rule {
        id = "ecs-ec2-archiving"

        expiration {
          days = 365
        }

        filter {
            and {
                prefix = "market-data-logs-algorithms/"
                tags = {
                    archive = "true"
                    datalife = "long"
                }
            }
        }
        status = "Enabled"

        transition {
          days = 30
          storage_class = "INTELLIGENT_TIERING"
        }

        transition {
            days = 180
            storage_class = "GLACIER"
        }
    }
}


# S3 Bucket for SageMaker Training Data and Model Artifacts
resource "aws_s3_bucket" "sagemaker_bucket" {
  bucket = "hft-sagemaker-bucket-talha"
}

# Lifecycle Rule for Training Data and Model Artifacts
resource "aws_s3_bucket_lifecycle_configuration" "hft_sagemaker_config" {
  bucket = aws_s3_bucket.sagemaker_bucket.id

  rule {
    id = "hft-sagemaker-archiving"

    expiration {
      days = 365
    }

    filter {
      and {
        prefix = "training-data-and-artifacts/"
        tags = {
          archive  = "true"
          datalife = "long"
        }
      }
    }

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}

# S3 Versioning Bucket
resource "aws_s3_bucket" "hft_sagemaker_versioning_bucket" {
  bucket = "hft-sagemaker-versioning-bucket-talha"
}


# Enable S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "hft_sagemaker_versioning" {
  bucket = aws_s3_bucket.sagemaker_bucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning Lifecycle Rule for Training Data and Model Artifacts
resource "aws_s3_bucket_lifecycle_configuration" "hft_sagemaker_versioning_bucket_config" {
  bucket = aws_s3_bucket.hft_sagemaker_versioning_bucket.id

  rule {
    id = "hft-sagemaker-versioning-bucket-config"

    filter {
      prefix = "versioning-training-data-and-artifacts/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "INTELLIGENT_TIERING"
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }
}

# S3 Bucket for Kinesis 
resource "aws_s3_bucket" "kinesis_bucket" {
  bucket = "kinesis-bucket-talha"
}

# Lifecycle Rule for Processed Streamed Data
resource "aws_s3_bucket_lifecycle_configuration" "kinesis_config" {
  bucket = aws_s3_bucket.kinesis_bucket.id

  rule {
    id = "kinesis-archiving"

    expiration {
      days = 365
    }

    filter {
      and {
        prefix = "processed-data-stream-storage/"
        tags = {
          archive  = "true"
          datalife = "long"
        }
      }
    }

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}

# S3 Bucket to store CodePipeline Artifacts
resource "aws_s3_bucket" "codepipeline_artifacts" {
  bucket = "codepipeline-artifacts-talha"
}

# Lifecycle Rule for CodePipeline
resource "aws_s3_bucket_lifecycle_configuration" "hft_codepipeline_config" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id

  rule {
    id = "codepipeline-archiving"

    expiration {
      days = 365
    }

    filter {
      and {
        prefix = "codepipeline-artifacts/"
        tags = {
          archive  = "true"
          datalife = "long"
        }
      }
    }

    status = "Enabled"

    transition {
      days          = 30
      storage_class = "INTELLIGENT_TIERING"
    }

    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}

# S3 CodePipeline Versioning Bucket
resource "aws_s3_bucket" "codepipeline_artifacts_versioning_bucket" {
  bucket = "codepipeline-artifacts-versioning-bucket-talha"
}


# Enable S3 Bucket Versioning
resource "aws_s3_bucket_versioning" "codepipeline_artifacts_versioning" {
  bucket = aws_s3_bucket.codepipeline_artifacts.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Versioning Lifecycle Rule for CodePipeline
resource "aws_s3_bucket_lifecycle_configuration" "codepipeline_artifacts_versioning_bucket_config" {
  bucket = aws_s3_bucket.codepipeline_artifacts_versioning_bucket.id

  rule {
    id = "codepipeline-artifacts-versioning-bucket-config"

    filter {
      prefix = "versioning-codepipeline-artifacts/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 365
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "INTELLIGENT_TIERING"
    }

    noncurrent_version_transition {
      noncurrent_days = 180
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }
}

# VPC Endpoint for S3
resource "aws_vpc_endpoint" "s3_vpc_endpoint" {
  vpc_id = aws_vpc.main_vpc.id
  service_name = "com.amazonaws.eu-west-2.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = aws_route_table.private_rt[*].id
}


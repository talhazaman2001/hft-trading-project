# ECR repositories creation
resource "aws_ecr_repository" "trade_signal_processor" {
  name                 = "trade-signal-processor"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "market_data_ingestor" {
  name                 = "market-data-ingestor"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "risk_management_service" {
  name                 = "risk-management-service"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Add outputs for repository URIs for the ECS tasks to use
output "trade_signal_processor_ecr_uri" {
  value = aws_ecr_repository.trade_signal_processor.repository_url
}

output "market_data_ingestor_ecr_uri" {
  value = aws_ecr_repository.market_data_ingestor.repository_url
}

output "risk_management_service_ecr_uri" {
  value = aws_ecr_repository.risk_management_service.repository_url
}
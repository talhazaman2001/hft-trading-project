# ECR repositories creation
resource "aws_ecr_repository" "trade_signal_processing" {
  name                 = "trade-signal-processing"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }
}

resource "aws_ecr_repository" "market_data_ingestion" {
  name                 = "market-data-ingestion"
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
output "trade_signal_processing_ecr_uri" {
  value = aws_ecr_repository.trade_signal_processing.repository_url
}

output "market_data_ingestion_ecr_uri" {
  value = aws_ecr_repository.market_data_ingestion.repository_url
}

output "risk_management_service_ecr_uri" {
  value = aws_ecr_repository.risk_management_service.repository_url
}
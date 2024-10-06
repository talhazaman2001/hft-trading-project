# API Gateway to forward user requests to ALB
resource "aws_api_gateway_rest_api" "hft_api" {
  name        = "HFTTradingAPI"
  description = "API for HFT architecture"
}

resource "aws_api_gateway_resource" "hft_resource" {
  rest_api_id = aws_api_gateway_rest_api.hft_api.id
  parent_id   = aws_api_gateway_rest_api.hft_api.root_resource_id
  path_part   = "trading"
}

# GET Method to request trading data (API -> ALB -> EKS)
resource "aws_api_gateway_method" "get_trading_data" {
  rest_api_id   = aws_api_gateway_rest_api.hft_api.id
  resource_id   = aws_api_gateway_resource.hft_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

# Method Response for GET Method (status code 200 = GET Method Successful)
resource "aws_api_gateway_method_response" "get_method_response" {
  rest_api_id = aws_api_gateway_rest_api.hft_api.id
  resource_id = aws_api_gateway_resource.hft_resource.id
  http_method = "GET"
  status_code = "200"
}

# Create WAFv2 Web ACL for API Gateway
resource "aws_wafv2_web_acl" "hft_waf_acl" {
    name = "hft-ddos-protection"
    scope = "REGIONAL"
    description = "WAF ACL for DDos Protection in HFT environment"

    default_action {
      allow {}
    }

    # Rule to block specific IP ranges
    rule {
        name = "IPBlockRule"
        priority = 1

        action {
          block {}
        }

        statement {
          ip_set_reference_statement {
            arn = aws_wafv2_ip_set.my_ip_set.arn
          }
        }

        visibility_config {
          cloudwatch_metrics_enabled = true
          metric_name = "IPBlockRule"
          sampled_requests_enabled = true
        }
    }

    # Rule to limit rate of requests per IP
    rule {
      name = "RateLimitRule"
      priority = 2

      action {
        block {}
      }

      statement {
        rate_based_statement {
          limit = 2000
          aggregate_key_type = "IP"
        }
      }

      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name = "RateLimitRule"
        sampled_requests_enabled = true
      }
    }

    # Web ACL visibility configuration
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name = "HFTDDoSProtectionACL"
      sampled_requests_enabled = true
    }
}

# IP set for blocking specific IP ranges
resource "aws_wafv2_ip_set" "my_ip_set" {
    name = "my-ip-set"
    scope = "REGIONAL"
    ip_address_version = "IPV4"

    addresses = ["203.0.113.0/24", "198.51.100.0/24"] # Example IP range to block
}

# Associate WAF Web ACL with API Gateway
resource "aws_wafv2_web_acl_association" "api_gateway_association" {
  resource_arn = aws_api_gateway_rest_api.hft_api.execution_arn
  web_acl_arn = aws_wafv2_web_acl.hft_waf_acl.arn
}

# Enable Shield Advanced for API Gateway (critical for DDoS protection)
resource "aws_shield_protection" "api_shield_protection" {
  name = "hft-api-shield-protection"
  resource_arn = aws_api_gateway_rest_api.hft_api.execution_arn
}

# Enable Shield Advanced for ALB
resource "aws_shield_protection" "alb_shield_protection" {
  name = "hft-alb-shield-protection"
  resource_arn = aws_lb.ecs_alb.arn
}




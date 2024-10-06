# Create a Direct Connect Connection
resource "aws_dx_connection" "my_dx_connection" {
    name = "my-direct-connect"
    bandwidth = "100Gbps"
    location = "Equinix LD5"
    provider_name = "Equinix"
}

# Create a Direct Connect Gateway
resource "aws_dx_gateway" "my_dx_gateway" {
    name = "my-dx-gateway"
    amazon_side_asn = "64512"
}

# Create Transit Gateway to connect Direct Connect to the VPC
resource "aws_ec2_transit_gateway" "my_transit_gateway" {   
    amazon_side_asn = "64512"
    description = "My Transit Gateway"
}

# Transit Gateway Association
resource "aws_dx_gateway_associaton" "my_dx_gw_assoc" {
    dx_gateway_id = aws_dx_gateway.my_dx_gateway.id
    allowed_prefixes = ["10.0.0.0/16"] # Prefix for the on-prem network
    transit_gateway_id = aws_ec2_transit_gateway.my_transit_gateway.idd
}

# Add Route to allow Direct Connect Traffic to VPC
resource "aws_route" "tgw_route" {
    route_table_id = aws_route_table.private_rt.id
    destination_cidr_block = "0.0.0.0/0"
    transit_gateway_id = aws_ec2_transit_gateway.my_transit_gateway.id
}

# IAM Role for Direct Connect
resource "aws_iam_role" "dx_role" {
    name = "direct-connect-role"

    assume_role_policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Principal = {
                    Service = "directconnect.amazonaws.com"
                },
                Action = "sts:AssumeRole"
            }
        ]
    })
}

# IAM Policy for Direct Connect
resource "aws_iam_policy" "dx_policy" {
    name = "direct-connect-policy"
    
    policy = jsonencode({
        Version = "2012-10-17",
        Statement = [
            {
                Effect = "Allow",
                Action = [
                    "directconnect:DescribeConnections",
                    "directconnect:CreateDirectConnectGateway",
                    "directconnect:DeleteDirectConnectGateway",
                    "directconnect:DescribeDirectConnectGateways",
                    "directconnect:AssociateDirectConnectGateway",
                    "directconnect:CreateTransitVirtualInterface",
                    "directconnect:DescribeVirtualTransitInterface",
                    "directconnect:DeleteVirtualTransitInterface",
                    "ec2:DescribeTransitGateways",
                    "ec2:CreateTransitGateway",
                    "ec2:DescribeRouteTables",
                    "ec2:CreateRoute",
                    "ec2:DeleteRoute"
                ],
                Resource = "*"
            }
        ]
    })
}

resource "aws_iam_role_policy_attachment" "dx_policy_attach" {
    role = aws_iam_policy.dx_role.name
    policy_arn = aws_iam_policy.dx_policy.arn
}


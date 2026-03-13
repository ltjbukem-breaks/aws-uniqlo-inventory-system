# ============================================
# VPC
# ============================================

# Create VPC
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

# ============================================
# Internet Gateway (for public subnet)
# ============================================

# Create Internet Gateway
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/internet_gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

# ============================================
# Subnets
# ============================================

# Create public subnet (for VPC endpoints)
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.availability_zones[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-subnet"
  }
}

# Create private subnets (for RDS and Lambda)
# Docs: https://developer.hashicorp.com/terraform/language/meta-arguments/count
resource "aws_subnet" "private" {
  count = 2 # Create 2 private subnets (RDS requirement)

  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.${10 + count.index}.0/24" # 10.0.10.0/24, 10.0.11.0/24
  availability_zone = var.availability_zones[count.index]

  tags = {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
  }
}

# ============================================
# Route Tables
# ============================================

# Create route table for public subnet
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  # Add route to Internet Gateway
  route {
    cidr_block = "0.0.0.0/0" # All traffic
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

# Associate public subnet with public route table
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/route_table_association
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Create route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # No routes to internet - private subnets stay isolated
  # VPC endpoints will be added next

  tags = {
    Name = "${var.project_name}-private-rt"
  }
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = 2

  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# ============================================
# Security Groups
# ============================================

# Create Lambda security group (no rules yet)
resource "aws_security_group" "lambda" {
  name        = "${var.project_name}-lambda-sg"
  description = "Security group for Lambda functions"
  vpc_id      = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-lambda-sg"
  }
}

# Create RDS security group (no rules yet)
resource "aws_security_group" "rds" {
  name        = "${var.project_name}-rds-sg"
  description = "Security group for RDS PostgreSQL"
  vpc_id      = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-rds-sg"
  }
}

# Create VPC Endpoints security group (no rules yet)
resource "aws_security_group" "vpc_endpoints" {
  name        = "${var.project_name}-vpc-endpoints-sg"
  description = "Security group for VPC endpoints"
  vpc_id      = aws_vpc.main.id
  
  tags = {
    Name = "${var.project_name}-vpc-endpoints-sg"
  }
}

# Now add rules as separate resources (no circular dependency)

# Lambda egress to RDS
resource "aws_security_group_rule" "lambda_to_rds" {
  type                     = "egress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.lambda.id
  source_security_group_id = aws_security_group.rds.id
  description              = "Allow Lambda to connect to RDS"
}

# Lambda egress to VPC Endpoints (HTTPS)
resource "aws_security_group_rule" "lambda_to_vpc_endpoints" {
  type              = "egress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = aws_security_group.lambda.id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "Allow Lambda to connect to VPC Endpoints via HTTPS"
}

# RDS ingress from Lambda
resource "aws_security_group_rule" "rds_from_lambda" {
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.rds.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "Allow RDS to accept connections from Lambda"
}

# VPC Endpoints ingress from Lambda
resource "aws_security_group_rule" "vpc_endpoints_from_lambda" {
  type                     = "ingress"
  from_port                = 443
  to_port                  = 443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.vpc_endpoints.id
  source_security_group_id = aws_security_group.lambda.id
  description              = "Allow VPC Endpoints to accept HTTPS from Lambda"
}

# ============================================
# VPC Endpoints (Free tier alternative to NAT Gateway)
# ============================================

# Create VPC endpoint for S3
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.name}.s3" # e.g., com.amazonaws.us-east-1.s3
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id]

  tags = {
    Name = "${var.project_name}-s3-endpoint"
  }
}

# Create VPC endpoint for Secrets Manager
resource "aws_vpc_endpoint" "secrets_manager" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${data.aws_region.current.name}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-secretsmanager-endpoint"
  }
}

# ============================================
# Data Sources
# ============================================

# Get current AWS region
# Docs: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/region
data "aws_region" "current" {}

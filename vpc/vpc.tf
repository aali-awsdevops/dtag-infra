# ============================================================
# VPC FOR DTAG INFRA
# ============================================================

resource "aws_vpc" "dtag_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "dtag-vpc"
  }
}


# ============================================================
# CLOUDWATCH LOG GROUP FOR VPC FLOW LOGS
# ============================================================

resource "aws_cloudwatch_log_group" "dtag_vpc_flow_log_group" {
  name              = "/aws/vpc/dtag-vpc-flow-logs"
  retention_in_days = 5
}


# ============================================================
# IAM ROLE FOR VPC FLOW LOGS
# ============================================================

resource "aws_iam_role" "dtag_vpc_flow_log_role" {
  name = "dtag-vpc-flow-log-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }

        Action = "sts:AssumeRole"
      }
    ]
  })
}


# ============================================================
# IAM POLICY FOR CLOUDWATCH LOGS
# ============================================================

resource "aws_iam_role_policy" "dtag_vpc_flow_log_policy" {
  name = "dtag-vpc-flow-log-policy"
  role = aws_iam_role.dtag_vpc_flow_log_role.id

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]

        Resource = "*"
      }
    ]
  })
}


# ============================================================
# VPC FLOW LOGS
# ============================================================

resource "aws_flow_log" "dtag_vpc_flow_log" {
  traffic_type = "ALL"
  vpc_id       = aws_vpc.dtag_vpc.id

  log_destination = aws_cloudwatch_log_group.dtag_vpc_flow_log_group.arn
  iam_role_arn    = aws_iam_role.dtag_vpc_flow_log_role.arn

  depends_on = [
    aws_iam_role_policy.dtag_vpc_flow_log_policy
  ]
}


# ============================================================
# SUBNETS FOR DTAG INFRA
# ============================================================

locals {
  subnets = {
    "public-dtagsubnet-1" = {
      cidr_block        = var.subnet_cidr_block[0]
      availability_zone = var.availability_zones[0]
    }

    "private-dtag-subnet-1" = {
      cidr_block        = var.subnet_cidr_block[1]
      availability_zone = var.availability_zones[0]
    }

    "public-dtag-subnet-2" = {
      cidr_block        = var.subnet_cidr_block[2]
      availability_zone = var.availability_zones[1]
    }

    "private-subnet-2" = {
      cidr_block        = var.subnet_cidr_block[3]
      availability_zone = var.availability_zones[1]
    }
  }
}


resource "aws_subnet" "dtag_subnets" {
  for_each = local.subnets

  vpc_id                  = aws_vpc.dtag_vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = strcontains(each.key, "public")

  tags = {
    Name = each.key
  }
}


# ============================================================
# INTERNET GATEWAY
# ============================================================

resource "aws_internet_gateway" "dtag_igw" {
  vpc_id = aws_vpc.dtag_vpc.id

  tags = {
    Name = "dtag-igw"
  }
}


# ============================================================
# ELASTIC IPs FOR NAT GATEWAYS
#
# 2 NAT Gateways = 2 EIPs
# One NAT Gateway per AZ
# ============================================================

resource "aws_eip" "dtag_nat_eip" {
  for_each = {
    "public-dtagsubnet-1"  = "public-dtagsubnet-1"
    "public-dtag-subnet-2" = "public-dtag-subnet-2"
  }

  domain = "vpc"

  tags = {
    Name = "${each.key}-nat-eip"
  }
}


# ============================================================
# NAT GATEWAYS
#
# NAT Gateway 1 -> Public Subnet 1 -> AZ1
# NAT Gateway 2 -> Public Subnet 2 -> AZ2
# ============================================================

resource "aws_nat_gateway" "dtag_nat_gw" {
  for_each = {
    "public-dtagsubnet-1"  = "public-dtagsubnet-1"
    "public-dtag-subnet-2" = "public-dtag-subnet-2"
  }

  allocation_id = aws_eip.dtag_nat_eip[each.key].id

  subnet_id = aws_subnet.dtag_subnets[each.value].id

  tags = {
    Name = "${each.key}-nat-gateway"
  }

  depends_on = [
    aws_internet_gateway.dtag_igw
  ]
}


# ============================================================
# PUBLIC ROUTE TABLES
#
# 2 Public Route Tables
# One per public subnet
# ============================================================

resource "aws_route_table" "dtag_public_route_tables" {
  for_each = {
    "public-dtagsubnet-1"  = "public-dtagsubnet-1"
    "public-dtag-subnet-2" = "public-dtag-subnet-2"
  }

  vpc_id = aws_vpc.dtag_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dtag_igw.id
  }

  tags = {
    Name = "${each.key}-rt"
  }
}


# ============================================================
# PRIVATE ROUTE TABLES
#
# Private Subnet 1 -> NAT Gateway 1
# Private Subnet 2 -> NAT Gateway 2
# ============================================================

resource "aws_route_table" "dtag_private_route_tables" {
  for_each = {
    "private-dtag-subnet-1" = "public-dtagsubnet-1"
    "private-subnet-2"      = "public-dtag-subnet-2"
  }

  vpc_id = aws_vpc.dtag_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dtag_nat_gw[each.value].id
  }

  tags = {
    Name = "${each.key}-rt"
  }
}


# ============================================================
# PUBLIC ROUTE TABLE ASSOCIATIONS
# ============================================================

resource "aws_route_table_association" "dtag_public_route_table_associations" {
  for_each = {
    "public-dtagsubnet-1"  = "public-dtagsubnet-1"
    "public-dtag-subnet-2" = "public-dtag-subnet-2"
  }

  subnet_id = aws_subnet.dtag_subnets[each.key].id

  route_table_id = aws_route_table.dtag_public_route_tables[each.value].id
}


# ============================================================
# PRIVATE ROUTE TABLE ASSOCIATIONS
# ============================================================

resource "aws_route_table_association" "dtag_private_route_table_associations" {
  for_each = {
    "private-dtag-subnet-1" = "private-dtag-subnet-1"
    "private-subnet-2"      = "private-subnet-2"
  }

  subnet_id = aws_subnet.dtag_subnets[each.key].id

  route_table_id = aws_route_table.dtag_private_route_tables[each.key].id
}

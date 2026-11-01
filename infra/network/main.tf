# 1. Virtual Private Cloud (VPC)
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "light-dynamodb-vpc"
  }
}

# 2. Internet Gateway (IGW) for public ingress
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "light-dynamodb-igw"
  }
}

# 3. Public Subnets (across 2 AZs)
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "light-dynamodb-public-subnet-${count.index + 1}-${var.availability_zones[count.index]}"
    Tier = "Public"
  }
}

# 4. Private Subnets (across 2 AZs, strictly isolated, zero NAT Gateway)
resource "aws_subnet" "private" {
  count                   = length(var.private_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = false

  tags = {
    Name = "light-dynamodb-private-subnet-${count.index + 1}-${var.availability_zones[count.index]}"
    Tier = "Private"
  }
}

# 5. Public Route Table & Routes
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "light-dynamodb-public-rtb"
  }
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# 6. Private Route Table & Routes (Internal VPC only: 10.0.0.0/16 -> local)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  # Implicit local route for var.vpc_cidr is managed by AWS automatically.
  # No default 0.0.0.0/0 route is added, keeping shards isolated and eliminating NAT Gateway costs.

  tags = {
    Name = "light-dynamodb-private-rtb"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 7. Baseline Security Group for Intra-VPC Cluster Communication
resource "aws_security_group" "cluster_internal" {
  name        = "light-dynamodb-cluster-internal-sg"
  description = "Allows internal TCP communication between Coordinator and Shards"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Intra-VPC all traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Allow all outbound intra-VPC traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = {
    Name = "light-dynamodb-cluster-internal-sg"
  }
}

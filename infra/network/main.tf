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

# 6. Private Route Table & Routes (Internal VPC + Gateway Endpoints, zero NAT Gateway)
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "light-dynamodb-private-rtb"
  }
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# 7. Free Gateway VPC Endpoints for S3 & DynamoDB (Post-Review Fix #1)
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.public.id]

  tags = {
    Name = "light-dynamodb-s3-endpoint"
  }
}

resource "aws_vpc_endpoint" "dynamodb" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = [aws_route_table.private.id, aws_route_table.public.id]

  tags = {
    Name = "light-dynamodb-dynamodb-endpoint"
  }
}

# 8. Role-Based Security Groups with SG-to-SG Referencing (Post-Review Fix #2)
resource "aws_security_group" "coordinator" {
  name        = "light-dynamodb-coordinator-sg"
  description = "Security group for Coordinator node in public subnet"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Client API requests (HTTP/gRPC)"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS client ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Outbound to Shards inside VPC on RPC/API ports"
    from_port   = 8080
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "Outbound HTTPS for AWS APIs, S3/DynamoDB Endpoints, and updates"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "light-dynamodb-coordinator-sg"
    Role = "Coordinator"
  }
}

resource "aws_security_group" "shard" {
  name        = "light-dynamodb-shard-sg"
  description = "Least-privilege SG for isolated Shard nodes (accepts only from Coordinator and self)"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Allow data/control plane requests ONLY from Coordinator SG"
    from_port       = 8080
    to_port         = 9090
    protocol        = "tcp"
    security_groups = [aws_security_group.coordinator.id]
  }

  ingress {
    description = "Allow replication/gossip traffic ONLY between Shards (self)"
    from_port   = 8080
    to_port     = 9090
    protocol    = "tcp"
    self        = true
  }

  egress {
    description = "Allow replication outbound to other Shards (self)"
    from_port   = 8080
    to_port     = 9090
    protocol    = "tcp"
    self        = true
  }

  egress {
    description     = "Allow HTTPS outbound ONLY to S3 and DynamoDB Gateway VPC Endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    prefix_list_ids = [aws_vpc_endpoint.s3.prefix_list_id, aws_vpc_endpoint.dynamodb.prefix_list_id]
  }

  tags = {
    Name = "light-dynamodb-shard-sg"
    Role = "Shard"
  }
}

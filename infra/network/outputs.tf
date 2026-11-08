output "vpc_id" {
  description = "The ID of the provisioned VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr_block" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_ids" {
  description = "List of IDs of public subnets (for Coordinator / Ingress)"
  value       = aws_subnet.public[*].id
}

output "private_subnet_ids" {
  description = "List of IDs of private subnets (for Shards / Replicas)"
  value       = aws_subnet.private[*].id
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = aws_internet_gateway.main.id
}

output "coordinator_sg_id" {
  description = "Security Group ID for Coordinator node"
  value       = aws_security_group.coordinator.id
}

output "shard_sg_id" {
  description = "Security Group ID for Shard nodes (least-privilege SG-to-SG)"
  value       = aws_security_group.shard.id
}

output "s3_endpoint_id" {
  description = "Gateway VPC Endpoint ID for Amazon S3"
  value       = aws_vpc_endpoint.s3.id
}

output "dynamodb_endpoint_id" {
  description = "Gateway VPC Endpoint ID for Amazon DynamoDB"
  value       = aws_vpc_endpoint.dynamodb.id
}

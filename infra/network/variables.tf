variable "aws_region" {
  description = "AWS region for all network resources (N. Virginia - allowed by Sandbox SCP)"
  type        = string
  default     = "us-east-1"
}

variable "vpc_cidr" {
  description = "Supernet CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "Availability Zones to distribute subnets across"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public ingress subnets (0x tier)"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for isolated private shard subnets (1x tier)"
  type        = list(string)
  default     = ["10.0.11.0/24", "10.0.12.0/24"]
}

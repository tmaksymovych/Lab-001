variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "role_name" {
  description = "Name of the assumable read-only role"
  type        = string
  default     = "LightDynamoDBReadOnlyRole"
}

variable "policy_name" {
  description = "Name of the custom read-only policy"
  type        = string
  default     = "LightDynamoDBReadOnlyPolicy"
}

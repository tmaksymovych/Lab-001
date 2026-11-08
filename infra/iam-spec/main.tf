data "aws_iam_policy_document" "read_only" {
  statement {
    sid    = "AllowReadOnlyAccess"
    effect = "Allow"
    actions = [
      "ec2:Describe*",
      "ec2:Get*",
      "dynamodb:BatchGetItem",
      "dynamodb:Describe*",
      "dynamodb:GetItem",
      "dynamodb:List*",
      "dynamodb:Query",
      "dynamodb:Scan",
      "s3:Get*",
      "s3:List*",
      "cloudwatch:Describe*",
      "cloudwatch:Get*",
      "cloudwatch:List*"
    ]
    resources = ["*"]
  }

  statement {
    sid       = "DenyAllMutations"
    effect    = "Deny"
    actions   = ["*:Create*", "*:Delete*", "*:Put*", "*:Update*", "*:Modify*"]
    resources = ["*"]
  }
}

# 2. IAM Policy Resource
resource "aws_iam_policy" "read_only" {
  name        = var.policy_name
  description = "Strict read-only policy allowing view/describe access with zero mutation rights"
  policy      = data.aws_iam_policy_document.read_only.json

  tags = {
    Milestone = "M1"
    Purpose   = "Task2-ReadOnlyPolicy"
  }
}

# 3. Trust Relationship Document (Permits assume-role from EC2 or delegated principals)
data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowPrincipalToAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

# 4. Assumable IAM Role Resource
resource "aws_iam_role" "read_only" {
  name               = var.role_name
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "Assumable role holding read-only inspection permissions"

  tags = {
    Milestone = "M1"
    Purpose   = "Task3-AssumableRole"
  }
}

# 5. Attachment between Role and Policy
resource "aws_iam_role_policy_attachment" "read_only_attach" {
  role       = aws_iam_role.read_only.name
  policy_arn = aws_iam_policy.read_only.arn
}

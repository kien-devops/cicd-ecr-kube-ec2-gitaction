resource "aws_iam_role" "worker_role" {
  name = "${var.project_name}-worker-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_policy" "ecr_pull" {
  name        = "${var.project_name}-ecr-pull-policy"
  description = "Allows EC2 instances to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ecr_pull_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.ecr_pull.arn
}

resource "aws_iam_policy" "secrets_access" {
  name        = "${var.project_name}-secrets-policy"
  description = "Allows EC2 instances to read secrets from AWS Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "secrets_access_attach" {
  role       = aws_iam_role.worker_role.name
  policy_arn = aws_iam_policy.secrets_access.arn
}

# The AmazonEKSWorkerNodePolicy contains more permissions than just ECR pull,
# but if you solely need ECR pull, the custom policy above is stricter and better.
# We will use the custom one.

resource "aws_iam_instance_profile" "worker_profile" {
  name = "${var.project_name}-worker-profile"
  role = aws_iam_role.worker_role.name
}
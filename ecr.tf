############################
# ECR + GitHub OIDC for CI
############################

# --- Inputs (override in terraform.tfvars if you like) ---
variable "ecr_repo_name" {
  type        = string
  description = "ECR repository name for the web app image"
  default     = "aws-lab/app-web"
}

variable "github_owner" {
  type        = string
  description = "GitHub org/user that hosts the repo"
  default     = "your-gh-user-or-org"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository name (without owner)"
  default     = "app-web"
}

# (aws_region usually already exists in your variables.tf)
variable "aws_region" {
  type        = string
  description = "AWS Region for ECR / IAM"
  default     = "eu-central-1"
}

# --- Who am I / account id ---
data "aws_caller_identity" "current" {}

# --- ECR repository ---
resource "aws_ecr_repository" "app" {
  name                 = var.ecr_repo_name
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration { scan_on_push = true }

  lifecycle_policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last 10 images",
      selection = {
        tagStatus   = "any",
        countType   = "imageCountMoreThan",
        countNumber = 10
      },
      action = { type = "expire" }
    }]
  })
}

# --- GitHub OIDC provider (needed once per account) ---
# If you already have this in another stack, you can remove this block and
# reference the existing provider's ARN in the role's trust policy.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com",
  ]

  # GitHub's OIDC root CA thumbprint (current)
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
  ]
}

# --- Trust policy so GitHub Actions can assume the role via OIDC ---
data "aws_iam_policy_document" "gh_actions_trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    # Limit to your repo (all refs); you can lock this down to a specific branch:
    # e.g., values = ["repo:${var.github_owner}/${var.github_repo}:ref:refs/heads/main"]
    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_owner}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "gh_actions_ecr" {
  name               = "gh-actions-ecr-push"
  assume_role_policy = data.aws_iam_policy_document.gh_actions_trust.json
}

# --- ECR push policy (scoped to this repo) ---
data "aws_iam_policy_document" "ecr_push" {
  # Needed to obtain a registry auth token (must be "*")
  statement {
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }

  # Repo-scoped actions
  statement {
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:CompleteMultipartUpload",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
      "ecr:DescribeRepositories",
      "ecr:ListImages"
    ]
    resources = [aws_ecr_repository.app.arn]
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "ecr-push-policy"
  policy = data.aws_iam_policy_document.ecr_push.json
}

resource "aws_iam_role_policy_attachment" "attach_ecr_push" {
  role       = aws_iam_role.gh_actions_ecr.name
  policy_arn = aws_iam_policy.ecr_push.arn
}

# --- Outputs for wiring your CI/CD ---
output "ecr_repo_uri" {
  value       = aws_ecr_repository.app.repository_url
  description = "Use as the image repository in your GitHub Actions workflow"
}

output "gh_actions_role_arn" {
  value       = aws_iam_role.gh_actions_ecr.arn
  description = "Set as role-to-assume in aws-actions/configure-aws-credentials"
}

output "ecr_registry_id" {
  value       = aws_ecr_repository.app.registry_id
  description = "AWS account ID of the ECR registry"
}

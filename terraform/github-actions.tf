module "github_oidc_provider" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-oidc-provider"
  version = "~> 6.0"

  url = "https://token.actions.githubusercontent.com"

  tags = {
    Name    = "github-actions-oidc"
    Project = "online-boutique"
  }
}

module "github_actions_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role"
  version = "~> 6.0"

  name = "${var.cluster_name}-github-actions-ecr"

  enable_github_oidc = true

  oidc_wildcard_subjects = [
    "${var.github_repository}:ref:refs/heads/${var.github_branch}"
  ]

  policies = {
    GitHubActionsECR = module.github_actions_ecr_policy.arn
  }


  tags = {
    Name    = "${var.cluster_name}-github-actions-ecr"
    Project = "online-boutique"
  }
}

module "github_actions_ecr_policy" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-policy"
  version = "~> 6.0"

  name        = "${var.cluster_name}-github-actions-ecr"
  description = "Allows GitHub Actions to push images to Online Boutique ECR repositories"

  policy = jsonencode({
    Version = "2012-10-17"

    Statement = [
      {
        Effect = "Allow"

        Action = [
          "ecr:GetAuthorizationToken"
        ]

        Resource = "*"
      },

      {
        Effect = "Allow"

        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:CompleteLayerUpload",
          "ecr:InitiateLayerUpload",
          "ecr:PutImage",
          "ecr:UploadLayerPart"
        ]

        Resource = [
          for repo in aws_ecr_repository.microservices :
          repo.arn
        ]
      }
    ]
  })
}

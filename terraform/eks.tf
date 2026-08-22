resource "aws_eks_cluster" "project_eks" {
  name     = "project-eks"
  role_arn = aws_iam_role.eks_cluster_role.arn
  version  = "1.36"

  vpc_config {
    subnet_ids = [
      data.aws_subnet.private_1.id,
      data.aws_subnet.private_2.id
    ]

    endpoint_private_access = false
    endpoint_public_access  = true

    public_access_cidrs = [
      "0.0.0.0/0"
    ]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy
  ]
}
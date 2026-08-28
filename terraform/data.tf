
data "aws_eks_cluster_auth" "project_eks" {
  name = aws_eks_cluster.project_eks.name
}

data "aws_eks_cluster" "project_eks" {
  name = var.cluster_name
}

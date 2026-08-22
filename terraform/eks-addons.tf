# 1. AWS VPC CNI Addon (Handles Pod networking natively in AWS VPC)
resource "aws_eks_addon" "vpc_cni" {
  cluster_name = aws_eks_cluster.project_eks.name
  addon_name   = "vpc-cni"


  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_cluster.project_eks
  ]
}

resource "aws_eks_addon" "coredns" {
  cluster_name = aws_eks_cluster.project_eks.name
  addon_name   = "coredns"


  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.project_nodes
  ]
}

resource "aws_eks_addon" "kube_proxy" {
  cluster_name = aws_eks_cluster.project_eks.name
  addon_name   = "kube-proxy"

  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  depends_on = [
    aws_eks_node_group.project_nodes
  ]
}

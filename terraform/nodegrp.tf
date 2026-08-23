resource "aws_eks_node_group" "project_nodes" {
  cluster_name = aws_eks_cluster.project_eks.name

  node_group_name = "project-node-group"

  node_role_arn = aws_iam_role.eks_nodegroup_role.arn

  subnet_ids = [
    data.aws_subnet.private_1.id,
    data.aws_subnet.private_2.id
  ]

  instance_types = ["c7i-flex.large"]

  capacity_type = "ON_DEMAND"

  scaling_config {
    desired_size = 1
    min_size     = 1
    max_size     = 1
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_ecr_read_only_policy
  ]
}
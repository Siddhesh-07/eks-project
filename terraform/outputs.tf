output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.project_eks.name
}

output "eks_cluster_endpoint" {
  description = "EKS Kubernetes API endpoint"
  value       = aws_eks_cluster.project_eks.endpoint
}

output "eks_cluster_version" {
  description = "EKS Kubernetes version"
  value       = aws_eks_cluster.project_eks.version
}

output "node_group_name" {
  description = "EKS managed node group name"
  value       = aws_eks_node_group.project_nodes.node_group_name
}

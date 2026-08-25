variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-09b1c64c0d5e5b304"
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_pvt1" {
  type    = string
  default = "subnet-0bc00b0686835113a"
}

variable "subnet_pvt2" {
  type    = string
  default = "subnet-098701274d0810681"
}

variable "cluster_name" {
  type    = string
  default = "project-eks"
}

variable "kubernetes_version" {
  type    = string
  default = "1.36"
}

variable "github_repository" {
  description = "GitHub repository in owner/repository format"
  type        = string
  default     = "Siddhesh-07@71758756/eks-project@1342643665" # get this by github cli- -- gh api repos/Siddhesh-07/eks-project/actions/oidc/customization/sub
}

variable "github_branch" {
  type    = string
  default = "main"
}
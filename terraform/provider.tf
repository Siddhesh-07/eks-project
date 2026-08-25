terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>6.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = aws_eks_cluster.project_eks.endpoint
  cluster_ca_certificate = base64decode(aws_eks_cluster.project_eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.project_eks.token
}

provider "helm" {
  kubernetes {
    host                   = aws_eks_cluster.project_eks.endpoint
    cluster_ca_certificate = base64decode(aws_eks_cluster.project_eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.project_eks.token
  }
}

resource "kubernetes_secret" "cart_redis" {
  metadata {
    name      = "cart-redis"
    namespace = "default"
  }

  type = "Opaque"

  data = {
    "redis-addr" = "${aws_elasticache_replication_group.redis.primary_endpoint_address}:6379"
  }
}
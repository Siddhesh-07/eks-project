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
  }
}

provider "aws" {
  region = var.aws_region
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster.token
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
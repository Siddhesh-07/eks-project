variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "vpc_id" {
  type    = string
  default = "vpc-09b1c64c0d5e5b304"
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

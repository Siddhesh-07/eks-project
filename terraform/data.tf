data "aws_vpc" "project-vpc" {
  id = var.vpc_id
}

data "aws_subnet" "private_1" {
  id = var.subnet_pvt1
}

data "aws_subnet" "private_2" {
  id = var.subnet_pvt2
}

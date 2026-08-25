locals {
  ecr_repositories = [
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice"
  ]
}

resource "aws_ecr_repository" "microservices" {
  for_each = toset(local.ecr_repositories)

  name                 = "online-boutique/${each.value}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = {
    Project   = "online-boutique"
    ManagedBy = "terraform"
    Service   = each.value
  }
}
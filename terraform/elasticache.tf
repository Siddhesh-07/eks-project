# ---------------------------------------------------------
# ElastiCache subnet group
# ---------------------------------------------------------

resource "aws_elasticache_subnet_group" "redis" {
  name = "online-boutique-redis-subnet-group"

  subnet_ids = [
    var.subnet_pvt1,
    var.subnet_pvt2
  ]

  tags = {
    Name = "online-boutique-redis-subnet-group"
  }
}


# ---------------------------------------------------------
# Security Group for ElastiCache
# ---------------------------------------------------------

resource "aws_security_group" "elasticache_redis" {
  name        = "online-boutique-elasticache-sg"
  description = "Security group dedicated to ElastiCache Redis"
  vpc_id      = var.vpc_id

  # Allow Redis traffic from inside the VPC
  ingress {
    description = "Redis access from EKS/VPC"
    from_port   = 6379
    to_port     = 6379
    protocol    = "tcp"

    cidr_blocks = [
      var.vpc_cidr
    ]
  }

  # Outbound traffic
  egress {
    description = "Allow outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "online-boutique-elasticache-sg"
  }
}


# ---------------------------------------------------------
# ElastiCache Redis Replication Group
# ---------------------------------------------------------

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id = "online-boutique-redis"

  description = "Redis for Online Boutique cart service"

  engine         = "redis"
  engine_version = "7.1"

  node_type = "cache.t3.micro"

  port = 6379

  # Single primary for this project
  num_cache_clusters = 1

  subnet_group_name = aws_elasticache_subnet_group.redis.name

  security_group_ids = [
    aws_security_group.elasticache_redis.id
  ]

  # Encryption
  at_rest_encryption_enabled = true
  transit_encryption_enabled = false

  # Automatic failover requires multiple nodes,
  # so keep this false for the basic setup.
  automatic_failover_enabled = false

  # Make this explicit for a learning/project environment.
  multi_az_enabled = false

  tags = {
    Name = "online-boutique-redis"
  }
}
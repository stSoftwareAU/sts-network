terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }

  required_version = ">= 0.14.9"
}

variable "area" {
  type        = string
  description = "The Area"
}

variable "department" {
  type        = string
  description = "The Department"
}

variable "region" {
  type        = string
  description = "The AWS region"
}

variable "reduced_redundancy" {
  type        = bool
  description = "Reduce the redundancy and save costs ( non production only)"
  default = false
}

variable "main_cidr_block" {
  type        = string
  description = "Address range for the virtual network in CIDR notation. CIDR must be a /21."
  validation {
    condition     = tonumber(regex("/(\\d+)", var.main_cidr_block)[0]) == 21
    error_message = "A CIDR range of /21 is required to support enough IPs."
  }
}

provider "aws" {
  region = var.region

}

module "main_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.main_cidr_block
  networks = [
    {
      name     = "Private-A"
      new_bits = 2
    },
    {
      name     = "Private-B"
      new_bits = 2
    },
    {
      name     = "Private-C"
      new_bits = 2
    },
    {
      name     = "Public-A"
      new_bits = 4
    },
    {
      name     = "Public-B"
      new_bits = 4
    },
    {
      name     = "Public-C"
      new_bits = 4
    }
  ]
}

locals {
  public_cidr_blocks  = { for k, v in module.main_subnet_addrs.network_cidr_blocks : k => v if substr(k, 0, 6) == "Public" }
  private_cidr_blocks = { for k, v in module.main_subnet_addrs.network_cidr_blocks : k => v if substr(k, 0, 6) != "Public" }
}

resource "aws_vpc" "main" {
  cidr_block           = var.main_cidr_block
  enable_dns_hostnames = true

  tags = {
    Name = "Main"
  }
}

/*
 * Subnet types. 
 * 
 * Name	     Description
 * --------  --------------------------------------------------------------------
 * ISOLATED	 Isolated Subnets do not route traffic to the Internet (in this VPC).
 * PRIVATE	 Subnet that routes to the internet, but not vice versa.
 * PUBLIC	   Subnet connected to the Internet.

 * https://docs.aws.amazon.com/cdk/api/latest/docs/@aws-cdk_aws-ec2.SubnetType.html
 */
resource "aws_subnet" "private" {
  for_each = local.private_cidr_blocks
  vpc_id   = aws_vpc.main.id

  availability_zone = join("", [var.region, lower(substr(each.key, -1, 1))])
  cidr_block        = each.value

  tags = {
    Name = each.key
    Type = "PRIVATE"
  }
}

resource "aws_subnet" "public" {
  for_each                = local.public_cidr_blocks
  vpc_id                  = aws_vpc.main.id
  map_public_ip_on_launch = true

  availability_zone = join("", [var.region, lower(substr(each.key, -1, 1))])
  cidr_block        = each.value

  tags = {
    Name = each.key
    Type = "PUBLIC"
  }
}

locals{
  nat_count=var.reduced_redundancy ? 1: length(aws_subnet.public)
}

resource "aws_eip" "nat" {
  count = local.nat_count
  vpc   = true

  tags = {
    Name = join("", ["EIP-", upper(substr(strrev(values(aws_subnet.public)[count.index].availability_zone), 0, 1))])
  }
}

resource "aws_nat_gateway" "nat" {
  count = local.nat_count

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = values(aws_subnet.public)[count.index].id

  tags = {
    Name = join("", ["NAT-", upper(substr(strrev(values(aws_subnet.public)[count.index].availability_zone), 0, 1))])
  }
}

resource "aws_internet_gateway" "public" {
  vpc_id = aws_vpc.main.id
  tags = {
    "Name" = "Public IG"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.public.id
  }
  tags = {
    Name = "Public"
  }
}

resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id = values(aws_subnet.public)[count.index].id

  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count = length(aws_subnet.private)

  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = var.reduced_redundancy ?aws_nat_gateway.nat[0].id: aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = join("", ["Private-", upper(substr(strrev(values(aws_subnet.public)[count.index].availability_zone), 0, 1))])
  }
}

resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)

  subnet_id = values(aws_subnet.private)[count.index].id

  route_table_id = aws_route_table.private[count.index].id
}

resource "aws_security_group" "allow_ssm" {
  name        = "allow_ssm"
  description = "Allow Session Manager traffic"
  vpc_id      = aws_vpc.main.id
  ingress = [
    {
      cidr_blocks = [
        var.main_cidr_block,
      ]
      description      = "SSM"
      from_port        = 443
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      protocol         = "tcp"
      security_groups  = []
      self             = false
      to_port          = 443
    },
  ]

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "Allow SSM"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = join("", ["com.amazonaws.", var.region, ".s3"])
  vpc_endpoint_type = "Gateway"
  tags = {
    Name = "S3 endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = join("", ["com.amazonaws.", var.region, ".ssm"])
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]
  tags = {
    Name = "SSM"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id              = aws_vpc.main.id
  service_name        = join("", ["com.amazonaws.", var.region, ".ec2messages"])
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]
  tags = {
    Name = "EC2 Messages"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id              = aws_vpc.main.id
  service_name        = join("", ["com.amazonaws.", var.region, ".ssmmessages"])
  vpc_endpoint_type   = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]
  tags = {
    Name = "SSM Messages"
  }
}

resource "aws_vpc_endpoint_subnet_association" "ssm" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ec2messages" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ec2messages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ssmmessages" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssmmessages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

/*
 * Log bucket
 */
resource "aws_s3_bucket" "logs" {
  bucket = join("-", [lower(var.department), "logs", lower(var.area), lower(var.region)])
  acl    = "private"

  tags = {
    Name        = "Logs"
    Environment = var.area
  }

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "log"
    enabled = true

    prefix = "/"

    tags = {
      rule      = "log"
      autoclean = "true"
    }

    noncurrent_version_expiration {
      days = 30
    }

    # abort_incomplete_multipart_upload_days=7

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "ONEZONE_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }

    expiration {
      days = 365

      expired_object_delete_marker = true
    }
  }
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
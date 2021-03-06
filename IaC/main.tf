terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.6"
    }
  }

  required_version = ">= 1.0.6"
}

/**
 * Standard variables
 */
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

variable "package" {
  type        = string
  description = "The Package"
  default     = "Unknown"
}

variable "who" {
  type        = string
  description = "Who did deployment"
  default     = "Unknown"
}

variable "digest" {
  type        = string
  description = "The docker image Digest"
  default     = "Unknown"
}

/* AWS provider and default tags */
provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Package    = var.package
      Area       = var.area
      Department = var.department
      Who        = var.who
      Digest     = var.digest
    }
  }
}

variable "main_cidr_block" {
  type        = string
  description = "Address range for the virtual network in CIDR notation. CIDR must be a /21."
  validation {
    condition     = tonumber(regex("/(\\d+)", var.main_cidr_block)[0]) == 21
    error_message = "A CIDR range of /21 is required to support enough IPs."
  }
}

data "aws_caller_identity" "current" {}

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
    },
    {
      name     = "Isolated-A"
      new_bits = 6
    },
    {
      name     = "Isolated-B"
      new_bits = 6
    },
    {
      name     = "Isolated-C"
      new_bits = 6
    },
  ]
}

locals {
  public_cidr_blocks  = { for k, v in module.main_subnet_addrs.network_cidr_blocks : k => v if substr(k, 0, 6)   == "Public" }
  private_cidr_blocks = { for k, v in module.main_subnet_addrs.network_cidr_blocks : k => v if substr(k, 0, 7)   == "Private" }
  isolated_cidr_blocks  = { for k, v in module.main_subnet_addrs.network_cidr_blocks : k => v if substr(k, 0, 8) == "Isolated" }
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
 resource "aws_subnet" "isolated" {
  for_each = local.isolated_cidr_blocks
  vpc_id   = aws_vpc.main.id

  availability_zone = join("", [var.region, lower(substr(each.key, -1, 1))])
  cidr_block        = each.value

  tags = {
    Name = each.key
    Type = "ISOLATED"
  }
}

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

locals {
  nat_count = lower(var.area) != "production" ? 1 : length(aws_subnet.public)
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
    nat_gateway_id = local.nat_count == 1 ? aws_nat_gateway.nat[0].id : aws_nat_gateway.nat[count.index].id
  }

  tags = {
    Name = join("", ["Private-", upper(substr(strrev(values(aws_subnet.public)[count.index].availability_zone), 0, 1))])
  }
}
resource "aws_route_table" "isolated" {
  count = length(aws_subnet.isolated)

  vpc_id = aws_vpc.main.id

  tags = {
    Name = join("", ["Isolated-", upper(substr(strrev(values(aws_subnet.public)[count.index].availability_zone), 0, 1))])
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

resource "aws_vpc_endpoint_route_table_association" "private-s3" {
  count = length(aws_subnet.private)

  route_table_id  = aws_route_table.private[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "isolated-s3" {
  count = length(aws_subnet.isolated)

  route_table_id  = aws_route_table.isolated[count.index].id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
}

resource "aws_vpc_endpoint_route_table_association" "public-s3" {
  route_table_id  = aws_route_table.public.id
  vpc_endpoint_id = aws_vpc_endpoint.s3.id
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

resource "aws_vpc_endpoint_subnet_association" "ssm-private" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ec2messages-private" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ec2messages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ssmmessages-private" {
  count           = length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssmmessages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

/*
 * Log bucket
 */
resource "aws_s3_bucket" "logs" {
  bucket = join("-", [lower(var.department), "logs", lower(var.area), lower(var.region)])

  tags = {
    Name        = "Logs"
    Environment = var.area
  }
}

resource "aws_s3_bucket_acl" "logs" {
  bucket = aws_s3_bucket.logs.id
  acl    = "private"
}

resource "aws_s3_bucket_server_side_encryption_configuration" "logs" {
  bucket = aws_s3_bucket.logs.bucket

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "logs" {
  bucket = aws_s3_bucket.logs.id

  rule {
    id      = "log"
    status = "Enabled"

    filter {
      prefix = "/"
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 60
      storage_class = "ONEZONE_IA"
    }

    transition {
      days          = 365 # Keep on-line for one year.
      storage_class = "GLACIER"
    }

    expiration {
      days = 2587 # Delete after 7 years and one month.

      expired_object_delete_marker = true
    }
  }
}

resource "aws_s3_bucket_versioning" "logs" {
  bucket = aws_s3_bucket.logs.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_policy" "logs" {
  bucket = aws_s3_bucket.logs.id
  policy = replace(
    replace(
      replace(
        file("policies/s3-logs.json"),
        "$${ACCOUNT_ID}",
        data.aws_caller_identity.current.account_id
      ),
      "$${BUCKET_NAME}",
      aws_s3_bucket.logs.bucket
    ),
    "$${ELB_ACCOUNT_ID}",
    "783225319266" # ap-southeast-2 	Asia Pacific (Sydney) 	
  )
}

resource "aws_s3_bucket_public_access_block" "logs" {
  bucket = aws_s3_bucket.logs.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

/**
 * Disable the default VPC.
 */
resource "aws_default_vpc" "default" {
  enable_dns_support   = false
  enable_dns_hostnames = false
  tags = {
    Name = "Do not use"
  }
}

# Log DNS queries 
#
# stats count( query_name) as numRequests by query_name
# | sort numRequests desc 
# | limit 20
resource "aws_cloudwatch_log_group" "DNS-lookup" {
  name              = join("/", ["", "route53", "DNS", "lookup", aws_vpc.main.tags["Name"]])
  retention_in_days = 90
}

resource "aws_route53_resolver_query_log_config" "DNS-lookup" {
  name            = "DNS-lookup"
  destination_arn = aws_cloudwatch_log_group.DNS-lookup.arn

}

resource "aws_route53_resolver_query_log_config_association" "DNS-lookup" {
  resolver_query_log_config_id = aws_route53_resolver_query_log_config.DNS-lookup.id
  resource_id                  = aws_vpc.main.id
}
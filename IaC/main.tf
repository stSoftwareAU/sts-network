terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }

  required_version = ">= 0.14.9"
}

variable "region"{
  type        = string
  description = "The AWS region"
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
  region=var.region

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
  public_cidr_blocks = { for k, v in module.main_subnet_addrs.network_cidr_blocks :  k => v if substr(k,0,6) == "Public"}
  private_cidr_blocks = { for k, v in module.main_subnet_addrs.network_cidr_blocks :  k => v if substr(k,0,6) != "Public"}
}


resource "aws_vpc" "main" {
  cidr_block = var.main_cidr_block
  enable_dns_hostnames=true

  tags = {
    Name = "Main"
  }
}

resource "aws_subnet" "private" {
  for_each = local.private_cidr_blocks
    vpc_id            = aws_vpc.main.id

    availability_zone = join( "",[var.region,lower(substr(each.key,-1,1)) ])
    cidr_block        = each.value
    
    tags={
      Name = each.key
    }
}

resource "aws_subnet" "public" {
  for_each = local.public_cidr_blocks
    vpc_id            = aws_vpc.main.id
    map_public_ip_on_launch = true

    availability_zone = join( "",[var.region,lower(substr(each.key,-1,1)) ])
    cidr_block        = each.value
    
    tags={
      Name = each.key
    }
}

resource "aws_eip" "nat" {
  count=length(aws_subnet.public)
  vpc = true

  tags = {
    Name = join( "",["EIP-",upper( substr(strrev(values(aws_subnet.public)[count.index].availability_zone),0,1) )])
  }
}

resource "aws_nat_gateway" "nat" {
  count=length(aws_subnet.public)

  allocation_id = aws_eip.nat[count.index].id
  subnet_id     = values(aws_subnet.public)[count.index].id

  tags = {
    Name = join( "",["NAT-",upper( substr(strrev(values(aws_subnet.public)[count.index].availability_zone),0,1) )])
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
    tags={
      Name = "Public"
  }
}

resource "aws_route_table_association" "public" {
  count=length(aws_subnet.public)

  subnet_id     = values(aws_subnet.public)[count.index].id

  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "private" {
  count=length(aws_subnet.private)

  vpc_id= aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id= aws_nat_gateway.nat[count.index].id
  }

  tags={
      Name = join( "",["Private-",upper( substr(strrev(values(aws_subnet.public)[count.index].availability_zone),0,1) )])
  }
}

resource "aws_route_table_association" "private" {
  count=length(aws_subnet.private)

  subnet_id     = values(aws_subnet.private)[count.index].id

  route_table_id =  aws_route_table.private[count.index].id
}

resource "aws_security_group" "allow_ssm" {
  name        = "allow_ssm"
  description = "Allow Session Manager traffic"
  vpc_id      = aws_vpc.main.id
  ingress                = [
    {
        cidr_blocks      = [
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
  vpc_id       = aws_vpc.main.id
  service_name = join( "",["com.amazonaws.", var.region,".s3"])
  vpc_endpoint_type = "Gateway"
  tags = {
    Name = "S3 endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id       = aws_vpc.main.id
  service_name = join( "",["com.amazonaws.", var.region,".ssm"])
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]
  tags = {
    Name = "SSM"
  }
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id       = aws_vpc.main.id
  service_name = join( "",["com.amazonaws.", var.region,".ec2messages"])
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]
  tags = {
    Name = "EC2 Messages"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id       = aws_vpc.main.id
  service_name = join( "",["com.amazonaws.", var.region,".ssmmessages"])
  vpc_endpoint_type = "Interface"
  private_dns_enabled = true
  security_group_ids = [
    aws_security_group.allow_ssm.id,
  ]  
  tags = {
    Name = "SSM Messages"
  }
}

resource "aws_vpc_endpoint_subnet_association" "ssm" {
  count=length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssm.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ec2messages" {
  count=length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ec2messages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

resource "aws_vpc_endpoint_subnet_association" "ssmmessages" {
  count=length(aws_subnet.private)
  vpc_endpoint_id = aws_vpc_endpoint.ssmmessages.id
  subnet_id       = values(aws_subnet.private)[count.index].id
}

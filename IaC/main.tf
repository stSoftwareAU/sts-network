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

variable "public_cidr_block" {  
  type        = string  
  description = "Address range for the virtual network in CIDR notation. CIDR must be a /16 or better."  
  default = "192.168.0.0/16"
  validation {    
    condition     = tonumber(regex("/(\\d+)", var.public_cidr_block)[0]) >= 16   
    error_message = "A CIDR range of /16 of more is required for the public VPC."  
  }
}

variable "public_new_bits" {  
  type        = number  
  description = "Public new bits per subnet"  
  default = 2
  validation {    
    condition     = var.public_new_bits>=2  
    error_message = "Must be more than 2."  
  }
  validation {    
    condition     = var.public_new_bits<20  
    error_message = "Must be less than 20."  
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
      name     = "Main-A"
      new_bits = 2
    },

    {
      name     = "Main-B"
      new_bits = 2
    },

    {
      name     = "Main-C"
      new_bits = 2
    }
  ]
}

module "public_subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.public_cidr_block
  networks = [
    {
      name     = "Public-A"
      new_bits = var.public_new_bits
    },

    {
      name     = "Public-B"
      new_bits = var.public_new_bits
    },

    {
      name     = "Public-C"
      new_bits = var.public_new_bits
    },
  ]
}

resource "aws_vpc" "public" {
  cidr_block = var.public_cidr_block
  tags = {
    Name = "Public"
  }
}


resource "aws_subnet" "public" {
  for_each = module.public_subnet_addrs.network_cidr_blocks
    vpc_id            = aws_vpc.public.id
    availability_zone = join( "",[var.region,lower(substr(each.key,-1,1)) ])

    cidr_block        = each.value
        
    tags={
      Name = each.key
    }
}

resource "aws_vpc" "main" {
  cidr_block = var.main_cidr_block
  tags = {
    Name = "Main"
  }
}

resource "aws_subnet" "main" {
  for_each = module.main_subnet_addrs.network_cidr_blocks
    vpc_id            = aws_vpc.main.id
    
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

resource "aws_internet_gateway" "nat_gateway" {
  vpc_id = aws_vpc.public.id
  tags = {
    "Name" = "NAT Gateway"
  }
}

resource "aws_route_table" "nat_gateway" {
  vpc_id = aws_vpc.public.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "nat_gateway" {
  count=length(aws_subnet.public)

  subnet_id     = values(aws_subnet.public)[count.index].id

  route_table_id = aws_route_table.nat_gateway.id
}
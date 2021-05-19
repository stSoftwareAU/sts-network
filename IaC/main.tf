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

# resource "aws_vpc" "main" {
#   cidr_block = module.subnet_addrs.base_cidr_block
#   enable_dns_support = true
#   enable_dns_hostnames = true

#   tags = {
#     Name = "main"
#   }
# }

module "subnet_addrs" {
  source = "hashicorp/subnets/cidr"

  base_cidr_block = var.main_cidr_block
  networks = [
    {
      name     = "ap-southeast-2a"
      new_bits = 2
    },
    {
      name     = "ap-southeast-2b"
      new_bits = 2
    },
    {
      name     = "ap-southeast-2c"
      new_bits = 2
    },
  ]
}

resource "aws_vpc" "main" {
  cidr_block = module.subnet_addrs.base_cidr_block
  tags = {
    Name = "main"
  }
}

resource "aws_subnet" "main" {
  for_each = module.subnet_addrs.network_cidr_blocks
    vpc_id            = aws_vpc.main.id
    availability_zone = each.key
    cidr_block        = each.value
    
    tags={
      Name = join( "",["Main Private-",upper( substr(strrev(each.key),0,1) )])
    }
}
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.39"
    }
  }

  required_version = ">= 0.14.9"
}

# variable "region"{
#   type        = string
#   description = "The AWS region"
# }

variable "main_cidr_block" {  
  type        = string  
  description = "Address range for the virtual network in CIDR notation. CIDR must be a /21."  
  validation {    
    condition     = tonumber(regex("/(\\d+)", var.base_cidr_block)[0]) == 21    
    error_message = "A CIDR range of /21 is required to support enough Pod IPs."  
  }
}

provider "aws" {
  region=var.region

}

resource "aws_vpc" "main" {
  cidr_block = var.main_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true

  tags = {
    Name = "main"
  }
}

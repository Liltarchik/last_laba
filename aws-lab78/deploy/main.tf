terraform {
  required_version = ">= 1.12.0, < 2.0.0"
  backend "s3" {
    region       = "eu-central-1"
    key          = "lab78/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "eu-central-1"
}

variable "image" {
  type = string
  validation {
    condition     = can(regex("^[0-9]{12}\\.dkr\\.ecr\\.eu-central-1\\.amazonaws\\.com/lab78-last-laba@sha256:[0-9a-f]{64}$", var.image))
    error_message = "Use the digest reference of the lab ECR image."
  }
}

variable "instance_profile" {
  type = string
}

variable "security_group" {
  type = string
}

variable "vpc_id" {
  type = string
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [var.vpc_id]
  }

  filter {
    name   = "default-for-az"
    values = ["true"]
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-kernel-*-x86_64"]
  }
  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

resource "aws_instance" "app" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = "t3.micro"
  subnet_id                   = sort(data.aws_subnets.default.ids)[0]
  vpc_security_group_ids      = [var.security_group]
  associate_public_ip_address = true
  iam_instance_profile        = var.instance_profile
  user_data_replace_on_change = true
  user_data                   = templatefile("${path.module}/user-data.sh", { image = var.image })
  tags                        = { Name = "lab78-flask", Project = "lab78-last-laba" }

  credit_specification {
    cpu_credits = "standard"
  }

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    volume_size           = 8
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }
}

output "service_url" {
  value = "http://${aws_instance.app.public_ip}"
}

terraform {
  required_version = ">= 1.12.0, < 2.0.0"
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

variable "existing_oidc_provider_arn" {
  type    = string
  default = ""
}

data "aws_caller_identity" "current" {}

data "aws_vpc" "default" {
  default = true
}

locals {
  account    = data.aws_caller_identity.current.account_id
  namespace  = "lab78-last-laba"
  ec2_prefix = "arn:aws:ec2:eu-central-1:${local.account}:"
  state_key  = "lab78/terraform.tfstate"
  pull_actions = [
    "ecr:BatchCheckLayerAvailability",
    "ecr:BatchGetImage",
    "ecr:GetDownloadUrlForLayer",
  ]
}

resource "aws_s3_bucket" "state" {
  bucket = "${local.namespace}-${local.account}-tf"
  tags   = { Project = local.namespace }
}

resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

resource "aws_ecr_repository" "app" {
  name = local.namespace
  tags = { Project = local.namespace }
}

resource "aws_security_group" "http" {
  name        = local.namespace
  description = "Public HTTP for Lab 7-8 Flask demo"
  vpc_id      = data.aws_vpc.default.id
  tags        = { Project = local.namespace }
}

resource "aws_vpc_security_group_ingress_rule" "http" {
  security_group_id = aws_security_group.http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
}

resource "aws_vpc_security_group_egress_rule" "all" {
  security_group_id = aws_security_group.http.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"
}

resource "aws_iam_role" "instance" {
  name = "${local.namespace}-instance"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "pull" {
  role = aws_iam_role.instance.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = "ecr:GetAuthorizationToken", Resource = "*" },
      { Effect = "Allow", Action = local.pull_actions, Resource = aws_ecr_repository.app.arn },
    ]
  })
}

resource "aws_iam_instance_profile" "app" {
  name = local.namespace
  role = aws_iam_role.instance.name
}

resource "aws_iam_openid_connect_provider" "github" {
  count          = var.existing_oidc_provider_arn == "" ? 1 : 0
  url            = "https://token.actions.githubusercontent.com"
  client_id_list = ["sts.amazonaws.com"]
}

resource "aws_iam_role" "github" {
  name = "${local.namespace}-github"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.existing_oidc_provider_arn != "" ? var.existing_oidc_provider_arn : aws_iam_openid_connect_provider.github[0].arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          "token.actions.githubusercontent.com:sub" = "repo:Liltarchik@158173169/last_laba@1472329806:ref:refs/heads/main"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "github" {
  role = aws_iam_role.github.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      { Effect = "Allow", Action = ["ec2:Describe*", "ecr:GetAuthorizationToken"], Resource = "*" },
      { Effect = "Allow", Action = concat(local.pull_actions, [
        "ecr:InitiateLayerUpload", "ecr:UploadLayerPart", "ecr:CompleteLayerUpload", "ecr:PutImage",
      ]), Resource = aws_ecr_repository.app.arn },
      { Effect = "Allow", Action = "s3:ListBucket", Resource = aws_s3_bucket.state.arn },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject"], Resource = "${aws_s3_bucket.state.arn}/${local.state_key}" },
      { Effect = "Allow", Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"], Resource = "${aws_s3_bucket.state.arn}/${local.state_key}.tflock" },
      { Effect = "Allow", Action = "iam:GetInstanceProfile", Resource = aws_iam_instance_profile.app.arn },
      { Effect = "Allow", Action = "iam:PassRole", Resource = aws_iam_role.instance.arn,
      Condition = { StringEquals = { "iam:PassedToService" = "ec2.amazonaws.com" } } },
      { Effect = "Allow", Action = "ec2:RunInstances", Resource = [
        "arn:aws:ec2:eu-central-1::image/*", "${local.ec2_prefix}subnet/*",
        "${local.ec2_prefix}network-interface/*", "${local.ec2_prefix}volume/*",
        "${local.ec2_prefix}security-group/${aws_security_group.http.id}"
      ] },
      { Effect = "Allow", Action = "ec2:RunInstances", Resource = "${local.ec2_prefix}instance/*",
      Condition = { StringEquals = { "aws:RequestTag/Project" = local.namespace } } },
      { Effect = "Allow", Action = "ec2:CreateTags", Resource = [
        "${local.ec2_prefix}instance/*", "${local.ec2_prefix}volume/*", "${local.ec2_prefix}network-interface/*"
      ], Condition = { StringEquals = { "ec2:CreateAction" = "RunInstances" } } },
      { Effect   = "Allow", Action = ["ec2:TerminateInstances", "ec2:CreateTags", "ec2:DeleteTags", "ec2:ModifyInstanceAttribute"],
        Resource = "${local.ec2_prefix}instance/*",
      Condition = { StringEquals = { "ec2:ResourceTag/Project" = local.namespace } } },
    ]
  })
}

output "github_variables" {
  value = {
    LAB78_AWS_ROLE       = aws_iam_role.github.arn
    LAB78_AWS_BUCKET     = aws_s3_bucket.state.id
    LAB78_AWS_REGISTRY   = aws_ecr_repository.app.repository_url
    LAB78_AWS_PROFILE    = aws_iam_instance_profile.app.name
    LAB78_AWS_HTTP_GROUP = aws_security_group.http.id
    LAB78_AWS_VPC        = data.aws_vpc.default.id
  }
}

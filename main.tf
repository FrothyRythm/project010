terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "key_name" {
  type = string
}

variable "gmail_user" { type = string }
variable "gmail_app_password" { type = string }
variable "github_token" { type = string }
variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

# Security group
resource "aws_security_group" "jenkins_sg" {
  name        = "jenkins-sg"
  description = "Allow Jenkins & SSH"

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for Jenkins
resource "aws_instance" "jenkins" {
  ami                    = "ami-0c42696027a8ede58" # Ubuntu 22.04 LTS (ap-south-1) — adjust if needed
  instance_type          = "t3.medium"
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]

  # user_data template receives secrets securely from local terraform variables
  user_data = templatefile("${path.module}/jenkins-userdata.sh.tpl", {
    gmail_user          = var.gmail_user,
    gmail_app_password  = var.gmail_app_password,
    github_token        = var.github_token,
    aws_access_key      = var.aws_access_key,
    aws_secret_key      = var.aws_secret_key,
    github_repo         = "https://github.com/FrothyRythm/project010.git"
  })

  tags = {
    Name = "Jenkins-Auto"
  }
}

# Elastic IP so you have stable URL
resource "aws_eip" "jenkins_eip" {
  instance = aws_instance.jenkins.id
  domain   = "vpc"
}

output "jenkins_url" {
  value = "http://${aws_eip.jenkins_eip.public_ip}:8080"
}

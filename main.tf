terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_instance" "jenkins" {
  ami                    = "ami-0f5ee92e2d63afc18" # Example Amazon Linux 2 AMI in ap-south-1
  instance_type          = var.instance_type
  key_name               = var.key_name
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/jenkins-userdata.sh.tpl", {
    github_repo_url        = var.github_repo_url,
    github_token           = var.github_token,
    gmail_user             = var.gmail_user,
    gmail_app_password     = var.gmail_app_password,
    jenkins_admin_user     = var.jenkins_admin_user,
    jenkins_admin_password = var.jenkins_admin_password,
    TF_VER                 = var.TF_VER
  })

  tags = {
    Name = "Jenkins-Server"
  }
}

output "jenkins_instance_ip" {
  description = "Public IP address of the Jenkins EC2 instance"
  value       = aws_instance.jenkins.public_ip
}

output "jenkins_url" {
  description = "Jenkins web interface URL"
  value       = "http://${aws_instance.jenkins.public_ip}:8080"
}


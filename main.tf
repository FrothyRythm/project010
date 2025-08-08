provider "aws" {
  region     = "ap-south-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

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

resource "aws_instance" "jenkins" {
  ami                    = data.aws_ami.amazon_linux_2.id
  instance_type          = "t2.micro"
  key_name               = "testkey"
  vpc_security_group_ids = [aws_security_group.jenkins_sg.id]
  associate_public_ip_address = true

  user_data = templatefile("${path.module}/jenkins-userdata.sh.tpl", {
    gmail_user         = var.gmail_user
    gmail_app_password = var.gmail_app_password
    github_repo        = var.github_repo
  })

  tags = {
    Name = "Jenkins-Server"
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.jenkins.public_ip}:8080"
}

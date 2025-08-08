provider "aws" {
  region = "ap-south-1"
}

variable "key_name" {
  type    = string
  default = "testkey"
}

variable "admin_email" {
  type    = string
  default = "admin@example.com" # change to your e-mail
}

resource "aws_security_group" "technova_sg" {
  name_prefix = "technova-sg-"
  description = "Allow required ports"

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Jenkins"
    from_port   = 8080
    to_port     = 8080
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

resource "aws_instance" "technova_app" {
  ami           = "ami-000e3d8f06cc3eab5" # Amazon Linux 2023 in ap-south-1
  instance_type = "t2.micro"
  key_name      = var.key_name

  vpc_security_group_ids = [aws_security_group.technova_sg.id]

  user_data = file("jenkins-userdata.sh")

  lifecycle {
    create_before_destroy = true
    ignore_changes        = [user_data]
    replace_triggered_by  = [filesha256("jenkins-userdata.sh")]
  }

  tags = {
    Name = "TechNova-Jenkins-Server"
  }
}

output "jenkins_url" {
  value = "http://${aws_instance.technova_app.public_ip}:8080"
}

output "debug_commands" {
  value = <<EOT
  # Check Jenkins service:
  ssh -i ~/.ssh/${var.key_name} ec2-user@${aws_instance.technova_app.public_ip} 'sudo systemctl status jenkins-custom'

  # View Jenkins logs:
  ssh -i ~/.ssh/${var.key_name} ec2-user@${aws_instance.technova_app.public_ip} 'sudo journalctl -u jenkins-custom -b --no-pager'

  # Get admin password:
  ssh -i ~/.ssh/${var.key_name} ec2-user@${aws_instance.technova_app.public_ip} 'sudo cat /var/lib/jenkins/secrets/initialAdminPassword'
  EOT
}

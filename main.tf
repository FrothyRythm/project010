provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "technova_sg" {
  name        = "technova-sg"
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
  key_name      = "testkey"

  vpc_security_group_ids = [aws_security_group.technova_sg.id]

  lifecycle {
  create_before_destroy = true
  ignore_changes = [user_data]
}


  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              exec > >(tee /var/log/user-data.log) 2>&1

              echo "User data started on $(date)"

              # Install Java
              dnf install -y java-17-amazon-corretto-devel

              # Create Jenkins user and workspace
              useradd -m -d /opt/jenkins -s /bin/bash jenkins || true
              mkdir -p /opt/jenkins
              chown jenkins:jenkins /opt/jenkins

              # Download Jenkins WAR
              curl -L -o /opt/jenkins/jenkins.war https://get.jenkins.io/war-stable/latest/jenkins.war
              chown jenkins:jenkins /opt/jenkins/jenkins.war
              chmod 755 /opt/jenkins/jenkins.war

              # Create custom systemd service
              cat <<EOT > /etc/systemd/system/jenkins-custom.service
              [Unit]
              Description=Custom Jenkins CI Server
              After=network.target

              [Service]
              User=jenkins
              Group=jenkins
              WorkingDirectory=/opt/jenkins
              ExecStart=/usr/bin/java -Djava.awt.headless=true -Xms128m -Xmx384m -jar /opt/jenkins/jenkins.war
              Restart=always

              [Install]
              WantedBy=multi-user.target
              EOT

              # Reload systemd and enable Jenkins
              systemctl daemon-reexec
              systemctl daemon-reload
              systemctl enable jenkins-custom
              systemctl start jenkins-custom

              # Install Docker
              dnf install -y docker
              systemctl enable docker
              systemctl start docker
              usermod -aG docker jenkins
              usermod -aG docker ec2-user

              # Wait for Jenkins to start
              sleep 60

              # Final service statuses
              echo "Java: $(java -version | head -1)"
              echo "Docker: $(docker --version)"
              echo "Jenkins Custom Service: $(systemctl is-active jenkins-custom)"
              EOF

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
  ssh -i ~/.ssh/testkey ec2-user@${aws_instance.technova_app.public_ip} 'sudo systemctl status jenkins-custom'

  # View Jenkins logs:
  ssh -i ~/.ssh/testkey ec2-user@${aws_instance.technova_app.public_ip} 'sudo journalctl -u jenkins-custom -b --no-pager'

  # Get admin password:
  ssh -i ~/.ssh/testkey ec2-user@${aws_instance.technova_app.public_ip} 'sudo find /opt/jenkins -name initialAdminPassword 2>/dev/null | xargs sudo cat'
  EOT
}

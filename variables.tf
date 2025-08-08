variable "aws_region" {
  type        = string
  description = "AWS region to deploy resources"
}

variable "instance_type" {
  type        = string
  default     = "t3.micro"
  description = "EC2 instance type for Jenkins"
}

variable "key_name" {
  type        = string
  description = "Name of the AWS key pair"
}

variable "github_repo_url" {
  type        = string
  description = "GitHub repository URL"
}

variable "github_token" {
  type        = string
  description = "GitHub Personal Access Token"
  sensitive   = true
}

variable "gmail_user" {
  type        = string
  description = "Gmail username for Jenkins notifications"
}

variable "gmail_app_password" {
  type        = string
  description = "Gmail App password for Jenkins notifications"
  sensitive   = true
}

variable "jenkins_admin_user" {
  type        = string
  description = "Jenkins admin username"
}

variable "jenkins_admin_password" {
  type        = string
  description = "Jenkins admin password"
  sensitive   = true
}

variable "TF_VER" {
  type        = string
  description = "Terraform version to install"
}

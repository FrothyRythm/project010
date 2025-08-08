variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.medium"
}

variable "key_name" {
  description = "EC2 key pair name (must exist in region)"
  type        = string
}

variable "github_repo_url" {
  description = "HTTPS GitHub repo URL (public)"
  type        = string
}

variable "github_token" {
  description = "GitHub personal access token (used to create webhook)"
  type        = string
  sensitive   = true
}

variable "gmail_user" {
  description = "Gmail address for notifications"
  type        = string
}

variable "gmail_app_password" {
  description = "Gmail App Password for SMTP"
  type        = string
  sensitive   = true
}

variable "jenkins_admin_user" {
  description = "Jenkins admin username"
  type        = string
  default     = "admin"
}

variable "jenkins_admin_password" {
  description = "Jenkins admin password"
  type        = string
  sensitive   = true
}

variable "TF_VER" {
  description = "Terraform version to install on Jenkins host"
  type        = string
  default     = "1.6.0"
}

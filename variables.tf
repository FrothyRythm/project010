variable "gmail_user" {
  type        = string
  description = "Gmail address for sending notifications"
}

variable "gmail_app_password" {
  type        = string
  description = "Gmail app password"
}

variable "aws_access_key" {
  type        = string
  description = "AWS Access Key"
}

variable "aws_secret_key" {
  type        = string
  description = "AWS Secret Key"
}

variable "github_repo" {
  type        = string
  description = "GitHub repository URL (public)"
}

variable "TF_VER" {
  type        = string
  description = "Terraform version for pipeline"
}

variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-south-1"
}

variable "key_name" {
  description = "Existing EC2 key pair name"
  type        = string
}

variable "gmail_user" { type = string }
variable "gmail_app_password" { type = string }
variable "github_token" { type = string }
variable "aws_access_key" { type = string }
variable "aws_secret_key" { type = string }

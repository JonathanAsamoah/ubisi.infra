variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "bucket_name" {
  description = "Logical bucket name, combined as {project}-{environment}-{bucket_name}"
  type        = string
}

variable "bucket" {
  description = "Name of the bucket to use to store image layers"
  default     = "ksubram2-docker-registry-bucket"
}

variable "region" {
  description = "Region to create the AWS resources"
  default     = "us-east-1"
}

variable "profile" {
  description = "Profile to use when provisioning AWS resources"
  default     = "default"
}

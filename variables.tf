variable "aws_region" {
  type    = string
  default = "eu-central-1"
}
variable "project" {
  type    = string
  default = "sre-app"
}
variable "vpc_id" { type = string } # from infra-core output
variable "public_subnet_ids" {
  type        = list(string)
  default     = [] # ← no nulls
  description = "Leave empty to auto-discover Tier=public subnets; set >=2 to override."

  validation {
    condition     = length(var.public_subnet_ids) == 0 || length(var.public_subnet_ids) >= 2
    error_message = "If provided, public_subnet_ids must contain at least two subnet IDs."
  }
}

variable "instance_type_app" {
  type    = string
  default = "t3.micro"
}
variable "instance_type_mon" {
  type    = string
  default = "t3.micro"
}

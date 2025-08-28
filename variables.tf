variable "aws_region" { type = string, default = "eu-central-1" }
variable "project"    { type = string, default = "sre-app" }
variable "vpc_id"     { type = string }                 # from infra-core output
variable "public_subnet_ids" {
  type = list(string)                                   # from infra-core outputs (pick 2)
  description = "Two public subnets in different AZs"
}
variable "instance_type_app" { type = string, default = "t3.micro" }
variable "instance_type_mon" { type = string, default = "t3.micro" }

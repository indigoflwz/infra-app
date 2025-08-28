# versions.tf (or any .tf file)

terraform {
  backend "s3" {
    bucket        = "aws-lab-s3-state"          # <-- exact bucket name, no spaces
    key           = "infra-app/dev/terraform.tfstate"
    region        = "eu-central-1"
    use_lockfile  = true                         # <-- replaces dynamodb_table
    encrypt       = true
  }
}

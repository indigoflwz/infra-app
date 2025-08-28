terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

provider "aws" { region = var.aws_region }

# --- Key pair (writes PEM locally) ---
resource "tls_private_key" "this" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "this" {
  key_name   = "${var.project}-key"
  public_key = tls_private_key.this.public_key_openssh
}

resource "local_file" "pem" {
  filename        = "${path.module}/${var.project}.pem"
  content         = tls_private_key.this.private_key_pem
  file_permission = "0600"
}

# --- Security Groups ---
resource "aws_security_group" "app_sg" {
  name        = "${var.project}-app-sg"
  description = "nginx in Docker"
  vpc_id      = var.vpc_id

  ingress { description = "SSH";  from_port = 22;   to_port = 22;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "HTTP"; from_port = 80;   to_port = 80;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-app-sg" }
}

resource "aws_security_group" "mon_sg" {
  name        = "${var.project}-mon-sg"
  description = "Prometheus + Grafana in Docker"
  vpc_id      = var.vpc_id

  ingress { description = "SSH";        from_port = 22;   to_port = 22;   protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "Prometheus"; from_port = 9090; to_port = 9090; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  ingress { description = "Grafana";    from_port = 3000; to_port = 3000; protocol = "tcp"; cidr_blocks = ["0.0.0.0/0"] }
  egress  { from_port = 0; to_port = 0; protocol = "-1"; cidr_blocks = ["0.0.0.0/0"] }

  tags = { Name = "${var.project}-mon-sg" }
}

# --- Latest Amazon Linux 2023 AMI (x86_64) ---
data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter { name = "name";         values = ["al2023-ami-2023.*-x86_64"] }
  filter { name = "architecture"; values = ["x86_64"] }
}

# --- Instances ---
resource "aws_instance" "app" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type_app
  subnet_id                   = var.public_subnet_ids[0]
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = file("${path.module}/user_data_app.sh")

  tags = { Name = "${var.project}-app" }
}

resource "aws_instance" "mon" {
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type_mon
  subnet_id                   = var.public_subnet_ids[1]
  vpc_security_group_ids      = [aws_security_group.mon_sg.id]
  key_name                    = aws_key_pair.this.key_name
  associate_public_ip_address = true
  user_data                   = templatefile("${path.module}/user_data_mon.sh", {
    APP_PRIVATE_IP = aws_instance.app.private_ip
  })

  tags = { Name = "${var.project}-mon" }
}

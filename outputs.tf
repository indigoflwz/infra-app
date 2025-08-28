output "ssh_key_path" { value = local_file.pem.filename }

output "app_public_ip" { value = aws_instance.app.public_ip }
output "mon_public_ip" { value = aws_instance.mon.public_ip }

output "app_url"       { value = "http://${aws_instance.app.public_ip}" }
output "prometheus_url"{ value = "http://${aws_instance.mon.public_ip}:9090" }
output "grafana_url"   { value = "http://${aws_instance.mon.public_ip}:3000" }

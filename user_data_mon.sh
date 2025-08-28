#!/bin/bash
set -euxo pipefail
dnf -y update
dnf -y install docker
systemctl enable --now docker

# Prometheus
docker run -d --name prometheus --restart always -p 9090:9090 \
  -v /opt/prometheus:/etc/prometheus \
  prom/prometheus:latest

# Create basic prometheus.yml (scrape self + app node_exporter later if you add it)
mkdir -p /opt/prometheus
cat >/opt/prometheus/prometheus.yml <<CONF
global:
  scrape_interval: 15s
scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
  # Example: scrape nginx container metrics if you add an exporter
  # - job_name: 'nginx'
  #   static_configs:
  #     - targets: ['${APP_PRIVATE_IP}:9113']
CONF
docker restart prometheus

# Grafana
docker run -d --name grafana --restart always -p 3000:3000 grafana/grafana:latest

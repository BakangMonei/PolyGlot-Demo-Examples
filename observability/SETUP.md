# Observability Stack Setup

## Prometheus, OpenTelemetry, Grafana Configuration

## Overview

This document provides setup instructions for the complete observability stack including metrics, logging, tracing, and alerting.

## Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  MySQL      │────▶│ Prometheus  │────▶│  Grafana    │
│  Exporter   │     │  + Thanos   │     │  Dashboards │
└─────────────┘     └─────────────┘     └─────────────┘
       │                    │                    │
       │                    ▼                    │
┌─────────────┐     ┌─────────────┐            │
│  MongoDB    │────▶│ Alertmanager│◀───────────┘
│  Exporter   │     │             │
└─────────────┘     └─────────────┘
       │
       ▼
┌─────────────┐
│OpenTelemetry│
│   + Jaeger  │
└─────────────┘
```

## Prometheus Setup

### Installation

```bash
# Download Prometheus
wget https://github.com/prometheus/prometheus/releases/download/v2.45.0/prometheus-2.45.0.linux-amd64.tar.gz
tar -xzf prometheus-2.45.0.linux-amd64.tar.gz
sudo cp prometheus-2.45.0.linux-amd64/prometheus /usr/local/bin/
sudo cp prometheus-2.45.0.linux-amd64/promtool /usr/local/bin/
```

### Configuration

```yaml
# prometheus.yml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: "banking-production"
    region: "us-east-1"

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
            - alertmanager:9093

# Rule files
rule_files:
  - "alerts/*.yml"

# Scrape configurations
scrape_configs:
  # Prometheus itself
  - job_name: "prometheus"
    static_configs:
      - targets: ["localhost:9090"]

  # MySQL exporters
  - job_name: "mysql"
    static_configs:
      - targets:
          - "mysql-node1:9104"
          - "mysql-node2:9104"
          - "mysql-node3:9104"
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
      - source_labels: [__address__]
        regex: 'mysql-node(\d+)'
        target_label: node

  # MongoDB exporters
  - job_name: "mongodb"
    static_configs:
      - targets:
          - "mongodb-node1:9216"
          - "mongodb-node2:9216"
          - "mongodb-node3:9216"
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance

  # Application metrics
  - job_name: "banking-app"
    static_configs:
      - targets:
          - "app1:8080"
          - "app2:8080"
          - "app3:8080"
    metrics_path: "/metrics"
```

### MySQL Exporter Setup

```bash
# Install MySQL Exporter
wget https://github.com/prometheus/mysqld_exporter/releases/download/v0.15.0/mysqld_exporter-0.15.0.linux-amd64.tar.gz
tar -xzf mysqld_exporter-0.15.0.linux-amd64.tar.gz
sudo cp mysqld_exporter /usr/local/bin/

# Create monitoring user
mysql -u root -p <<EOF
CREATE USER 'exporter'@'localhost' IDENTIFIED BY 'exporter_password';
GRANT PROCESS, REPLICATION CLIENT, SELECT ON *.* TO 'exporter'@'localhost';
FLUSH PRIVILEGES;
EOF

# Configure exporter
cat > /etc/mysql_exporter.cnf <<EOF
[client]
user=exporter
password=exporter_password
EOF

# Start exporter
sudo systemctl enable mysqld_exporter
sudo systemctl start mysqld_exporter
```

### MongoDB Exporter Setup

```bash
# Install MongoDB Exporter
wget https://github.com/percona/mongodb_exporter/releases/download/v0.39.0/mongodb_exporter-0.39.0.linux-amd64.tar.gz
tar -xzf mongodb_exporter-0.39.0.linux-amd64.tar.gz
sudo cp mongodb_exporter /usr/local/bin/

# Create monitoring user
mongosh <<EOF
use admin
db.createUser({
  user: "exporter",
  pwd: "exporter_password",
  roles: [
    { role: "clusterMonitor", db: "admin" },
    { role: "read", db: "local" }
  ]
})
EOF

# Start exporter
MONGODB_URI="mongodb://exporter:exporter_password@localhost:27017/?authSource=admin"
sudo systemctl enable mongodb_exporter
sudo systemctl start mongodb_exporter
```

## Thanos Setup (Long-term Retention)

### Installation

```bash
# Download Thanos
wget https://github.com/thanos-io/thanos/releases/download/v0.32.0/thanos-0.32.0.linux-amd64.tar.gz
tar -xzf thanos-0.32.0.linux-amd64.tar.gz
sudo cp thanos /usr/local/bin/
```

### Configuration

```yaml
# thanos-sidecar.yml
type: SIDECAR
config:
  objstore:
    type: S3
    config:
      bucket: thanos-data
      endpoint: s3.amazonaws.com
      access_key: ${AWS_ACCESS_KEY_ID}
      secret_key: ${AWS_SECRET_ACCESS_KEY}
  retention: 730d # 2 years
```

## Alertmanager Setup

### Installation

```bash
# Download Alertmanager
wget https://github.com/prometheus/alertmanager/releases/download/v0.26.0/alertmanager-0.26.0.linux-amd64.tar.gz
tar -xzf alertmanager-0.26.0.linux-amd64.tar.gz
sudo cp alertmanager-0.26.0.linux-amd64/alertmanager /usr/local/bin/
```

### Configuration

```yaml
# alertmanager.yml
global:
  resolve_timeout: 5m
  slack_api_url: "https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

route:
  group_by: ["alertname", "cluster", "service"]
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h
  receiver: "default"
  routes:
    - match:
        severity: critical
      receiver: "pagerduty"
      continue: true
    - match:
        severity: warning
      receiver: "slack"

receivers:
  - name: "default"
    email_configs:
      - to: "oncall@banking.com"
        headers:
          Subject: "Database Alert: {{ .GroupLabels.alertname }}"

  - name: "pagerduty"
    pagerduty_configs:
      - service_key: "${PAGERDUTY_SERVICE_KEY}"
        description: "{{ .GroupLabels.alertname }}"

  - name: "slack"
    slack_configs:
      - channel: "#database-alerts"
        title: "Database Alert"
        text: "{{ .GroupLabels.alertname }}: {{ .Annotations.summary }}"
```

### Alert Rules

```yaml
# alerts/database.yml
groups:
  - name: database_alerts
    interval: 30s
    rules:
      # MySQL Alerts
      - alert: MySQLDown
        expr: mysql_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MySQL instance is down"
          description: "MySQL instance {{ $labels.instance }} has been down for more than 1 minute."

      - alert: MySQLReplicationLag
        expr: mysql_slave_lag_seconds > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "MySQL replication lag is high"
          description: "MySQL replication lag on {{ $labels.instance }} is {{ $value }} seconds."

      - alert: MySQLConnectionPoolExhausted
        expr: mysql_global_status_threads_connected / mysql_global_variables_max_connections > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MySQL connection pool is nearly exhausted"
          description: "MySQL connection pool on {{ $labels.instance }} is {{ $value | humanizePercentage }} full."

      - alert: MySQLSlowQueries
        expr: rate(mysql_global_status_slow_queries[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of slow queries"
          description: "MySQL instance {{ $labels.instance }} has {{ $value }} slow queries per second."

      # MongoDB Alerts
      - alert: MongoDBDown
        expr: mongodb_up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "MongoDB instance is down"
          description: "MongoDB instance {{ $labels.instance }} has been down for more than 1 minute."

      - alert: MongoDBReplicationLag
        expr: mongodb_replset_member_replication_lag > 5
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "MongoDB replication lag is high"
          description: "MongoDB replication lag on {{ $labels.instance }} is {{ $value }} seconds."

      - alert: MongoDBConnectionPoolExhausted
        expr: mongodb_connections_current / mongodb_connections_available > 0.8
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "MongoDB connection pool is nearly exhausted"
          description: "MongoDB connection pool on {{ $labels.instance }} is {{ $value | humanizePercentage }} full."

      # Performance Alerts
      - alert: HighQueryLatency
        expr: histogram_quantile(0.99, rate(mysql_query_duration_seconds_bucket[5m])) > 0.1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High query latency detected"
          description: "P99 query latency on {{ $labels.instance }} is {{ $value }} seconds."

      - alert: HighTransactionRate
        expr: rate(mysql_global_status_questions[5m]) > 10000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High transaction rate"
          description: "Transaction rate on {{ $labels.instance }} is {{ $value }} queries per second."
```

## OpenTelemetry Setup

### Installation

```bash
# Install OpenTelemetry Collector
wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v0.85.0/otelcol-contrib_0.85.0_linux_amd64.tar.gz
tar -xzf otelcol-contrib_0.85.0_linux_amd64.tar.gz
sudo cp otelcol-contrib /usr/local/bin/otelcol
```

### Configuration

```yaml
# otel-collector.yml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    timeout: 10s
    send_batch_size: 1024
  memory_limiter:
    limit_mib: 512

exporters:
  jaeger:
    endpoint: jaeger:14250
    tls:
      insecure: true
  prometheus:
    endpoint: "0.0.0.0:8889"
  logging:
    loglevel: info

service:
  pipelines:
    traces:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [jaeger, logging]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [prometheus]
```

## Grafana Setup

### Installation

```bash
# Install Grafana
wget https://dl.grafana.com/enterprise/release/grafana-enterprise-10.0.0.linux-amd64.tar.gz
tar -xzf grafana-enterprise-10.0.0.linux-amd64.tar.gz
sudo cp -r grafana-10.0.0/* /usr/share/grafana/
```

### Dashboard Configuration

```json
// dashboards/mysql-overview.json
{
  "dashboard": {
    "title": "MySQL Overview",
    "panels": [
      {
        "title": "Connection Pool Utilization",
        "targets": [
          {
            "expr": "mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Replication Lag",
        "targets": [
          {
            "expr": "mysql_slave_lag_seconds",
            "legendFormat": "{{instance}}"
          }
        ]
      },
      {
        "title": "Query Latency (P99)",
        "targets": [
          {
            "expr": "histogram_quantile(0.99, rate(mysql_query_duration_seconds_bucket[5m]))",
            "legendFormat": "{{instance}}"
          }
        ]
      }
    ]
  }
}
```

## Key Performance Indicators

### Database KPIs

- Connection pool utilization: <80%
- Replication lag: <100ms
- Cache hit ratio: >95%
- Query latency P99: <50ms

### Query KPIs

- 95th percentile latency: <100ms
- Execution plan stability: >99%
- Slow query rate: <0.1%

### Business KPIs

- Failed transactions per million: <10
- Fraud detection accuracy: >99.5%
- Customer satisfaction: >4.5/5

## Monitoring Best Practices

1. **Comprehensive Coverage**: Monitor all layers (database, application, infrastructure)
2. **Meaningful Metrics**: Focus on business-impacting metrics
3. **Alert Fatigue**: Set appropriate thresholds to avoid false positives
4. **Dashboard Design**: Create dashboards for different audiences (SRE, DBA, business)
5. **Retention**: Balance retention with storage costs
6. **Automation**: Automate incident response where possible
7. **Documentation**: Document all alerts and dashboards

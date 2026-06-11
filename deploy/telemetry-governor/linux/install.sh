#!/bin/bash
set -e

echo "=== Telemetry Governor Engine Unified Installer ==="

# 1. Verification of Prerequisites
if ! [ -x "$(command -v docker)" ]; then
  echo "Error: docker is not installed. Please install Docker first." >&2
  exit 1
fi

if ! [ -x "$(command -v docker-compose)" ] && ! docker compose version &>/dev/null; then
  echo "Error: docker-compose is not installed. Please install docker-compose first." >&2
  exit 1
fi

# 2. Write configuration files in place
echo "Generating deployment files..."

cat << 'EOF' > docker-compose.yaml
version: '3.8'

services:
  clickhouse:
    image: clickhouse/clickhouse-server:latest
    container_name: telemetry-governor-clickhouse
    ports:
      - "9000:9000"
      - "8123:8123"
    environment:
      - CLICKHOUSE_DB=telemetry_governor
      - CLICKHOUSE_PASSWORD=telemetrypassword
      - CLICKHOUSE_DEFAULT_ACCESS_MANAGEMENT=1
    volumes:
      - clickhouse-data:/var/lib/clickhouse
    ulimits:
      nofile:
        soft: 262144
        hard: 262144
    restart: unless-stopped

  otel-collector:
    image: otel/opentelemetry-collector-contrib:latest
    container_name: telemetry-governor-collector
    volumes:
      - ./otel-collector-config.yaml:/etc/otelcol-contrib/config.yaml
    command: ["--config=/etc/otelcol-contrib/config.yaml"]
    ports:
      - "4317:4317" # OTLP gRPC
      - "4318:4318" # OTLP HTTP
    depends_on:
      - clickhouse
    restart: unless-stopped

volumes:
  clickhouse-data:
EOF

cat << 'EOF' > otel-collector-config.yaml
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318

processors:
  batch:
    send_batch_size: 8192
    timeout: 5s
    send_batch_max_size: 10240

exporters:
  clickhouse:
    endpoint: tcp://clickhouse:9000?database=telemetry_governor
    username: default
    password: telemetrypassword
    create_schema: true
    ttl: 24h

service:
  pipelines:
    logs:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
    traces:
      receivers: [otlp]
      processors: [batch]
      exporters: [clickhouse]
EOF

cat << 'EOF' > schema.sql
-- Create database for Telemetry Governor
CREATE DATABASE IF NOT EXISTS telemetry_governor;

-- 1. Logs Table Schema (OTLP Log Data Model compatible)
CREATE TABLE IF NOT EXISTS telemetry_governor.otel_logs (
    Timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    TimestampTime Date DEFAULT toDate(Timestamp),
    TraceId String CODEC(ZSTD(1)),
    SpanId String CODEC(ZSTD(1)),
    TraceFlags UInt32 CODEC(T64, ZSTD(1)),
    SeverityText LowCardinality(String) CODEC(ZSTD(1)),
    SeverityNumber Int32 CODEC(T64, ZSTD(1)),
    Body String CODEC(ZSTD(1)),
    ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    LogAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_res_attr_key mapKeys(ResourceAttributes) TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_log_attr_key mapKeys(LogAttributes) TYPE bloom_filter(0.01) GRANULARITY 1
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(TimestampTime)
ORDER BY (SeverityText, TimestampTime, Timestamp)
TTL Timestamp + INTERVAL 24 HOUR;

-- 2. Traces / Spans Table Schema (OTLP Trace Data Model compatible)
CREATE TABLE IF NOT EXISTS telemetry_governor.otel_traces (
    Timestamp DateTime64(9) CODEC(DoubleDelta, LZ4),
    TimestampDate Date DEFAULT toDate(Timestamp),
    TraceId String CODEC(ZSTD(1)),
    SpanId String CODEC(ZSTD(1)),
    ParentSpanId String CODEC(ZSTD(1)),
    TraceState String CODEC(ZSTD(1)),
    SpanName LowCardinality(String) CODEC(ZSTD(1)),
    SpanKind LowCardinality(String) CODEC(ZSTD(1)),
    Duration Int64 CODEC(T64, ZSTD(1)),
    StatusCode LowCardinality(String) CODEC(ZSTD(1)),
    StatusMessage String CODEC(ZSTD(1)),
    ResourceAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    SpanAttributes Map(LowCardinality(String), String) CODEC(ZSTD(1)),
    INDEX idx_trace_id TraceId TYPE bloom_filter(0.001) GRANULARITY 1,
    INDEX idx_span_name SpanName TYPE bloom_filter(0.01) GRANULARITY 1,
    INDEX idx_span_attr_key mapKeys(SpanAttributes) TYPE bloom_filter(0.01) GRANULARITY 1
) ENGINE = MergeTree()
PARTITION BY toYYYYMMDD(TimestampDate)
ORDER BY (SpanName, TimestampDate, Timestamp)
TTL Timestamp + INTERVAL 24 HOUR;
EOF

# 3. Startup Docker stack
echo "Starting ClickHouse and OTel Collector containers..."
if [ -x "$(command -v docker-compose)" ]; then
  docker-compose up -d
else
  docker compose up -d
fi

# 4. Wait for ClickHouse database server to become healthy
echo "Waiting for ClickHouse server to accept connections..."
until docker exec telemetry-governor-clickhouse clickhouse-client --password telemetrypassword --query "SELECT 1" &>/dev/null; do
  printf "."
  sleep 2
done
echo " ClickHouse is online!"

# 5. Apply ClickHouse database schema manually
echo "Applying database schema..."
docker exec -i telemetry-governor-clickhouse clickhouse-client --password telemetrypassword < schema.sql

echo "=================================================="
echo "Telemetry Governor Engine is now ready!"
echo "- ClickHouse TCP: 9000"
echo "- ClickHouse HTTP: 8123"
echo "- OTel Collector gRPC: 4317"
echo "- OTel Collector HTTP: 4318"
echo "=================================================="

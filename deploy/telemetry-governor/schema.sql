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
TTL Timestamp + INTERVAL 24 HOUR; -- Auto-expire telemetry after 24 hours

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
    Duration Int64 CODEC(T64, ZSTD(1)), -- In nanoseconds
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
TTL Timestamp + INTERVAL 24 HOUR; -- Auto-expire telemetry after 24 hours

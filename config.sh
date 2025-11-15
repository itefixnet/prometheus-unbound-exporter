#!/bin/bash
#
# Unbound Prometheus Exporter Configuration
# Source this file to configure the exporter settings
#

# Unbound Configuration
export UNBOUND_CONTROL="${UNBOUND_CONTROL:-unbound-control}"
export UNBOUND_HOST="${UNBOUND_HOST:-127.0.0.1}"
export UNBOUND_PORT="${UNBOUND_PORT:-8953}"

# Prometheus Exporter Configuration
export METRICS_PREFIX="${METRICS_PREFIX:-unbound}"

# HTTP Server Configuration
export LISTEN_PORT="${LISTEN_PORT:-9167}"
export LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0}"
export MAX_CONNECTIONS="${MAX_CONNECTIONS:-10}"
export TIMEOUT="${TIMEOUT:-30}"

# Logging Configuration
export LOG_LEVEL="${LOG_LEVEL:-info}"

# Performance Configuration
export CACHE_TTL="${CACHE_TTL:-5}"  # seconds to cache metrics (not implemented yet)

# Advanced Configuration
export ENABLE_HISTOGRAM_METRICS="${ENABLE_HISTOGRAM_METRICS:-true}"
export ENABLE_THREAD_METRICS="${ENABLE_THREAD_METRICS:-true}"
export ENABLE_MEMORY_METRICS="${ENABLE_MEMORY_METRICS:-true}"

# Remote Unbound Support
# If UNBOUND_HOST is not localhost, configure these if using certificates
export UNBOUND_CERT="${UNBOUND_CERT:-}"
export UNBOUND_KEY="${UNBOUND_KEY:-}"
export UNBOUND_CA="${UNBOUND_CA:-}"
#!/bin/bash
#
# Unbound Prometheus Exporter HTTP Server
# Uses socat to serve Prometheus metrics via HTTP
#

# Set strict error handling
set -euo pipefail

# Source configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Default configuration
LISTEN_PORT="${LISTEN_PORT:-9167}"
LISTEN_ADDRESS="${LISTEN_ADDRESS:-0.0.0.0}"
EXPORTER_SCRIPT="${EXPORTER_SCRIPT:-${SCRIPT_DIR}/unbound-exporter.sh}"
MAX_CONNECTIONS="${MAX_CONNECTIONS:-10}"
TIMEOUT="${TIMEOUT:-30}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to handle HTTP requests
handle_request() {
    local request_line
    local method
    local path
    local version
    
    # Read the request line
    IFS= read -r request_line
    
    # Parse the request line
    if [[ "$request_line" =~ ^([A-Z]+)[[:space:]]+([^[:space:]]+)[[:space:]]+(HTTP/[0-9]\.[0-9]) ]]; then
        method="${BASH_REMATCH[1]}"
        path="${BASH_REMATCH[2]}"
        version="${BASH_REMATCH[3]}"
    else
        # Invalid request format
        echo -e "HTTP/1.1 400 Bad Request\r"
        echo -e "Content-Type: text/plain\r"
        echo -e "Connection: close\r"
        echo -e "\r"
        echo "400 Bad Request"
        return
    fi
    
    # Read and discard headers
    while IFS= read -r line; do
        line=$(echo "$line" | tr -d '\r')
        [[ -z "$line" ]] && break
    done
    
    log "Request: $method $path from ${SOCAT_PEERADDR:-unknown}:${SOCAT_PEERPORT:-unknown}"
    
    # Route the request
    case "$path" in
        "/metrics")
            serve_metrics
            ;;
        "/health"|"/healthz")
            serve_health
            ;;
        "/")
            serve_index
            ;;
        *)
            serve_404 "$path"
            ;;
    esac
}

# Function to serve metrics endpoint
serve_metrics() {
    local metrics
    local exit_code=0
    
    # Generate metrics
    if ! metrics=$("$EXPORTER_SCRIPT" collect 2>&1); then
        exit_code=$?
        log "ERROR: Failed to collect metrics (exit code: $exit_code)"
        echo -e "HTTP/1.1 503 Service Unavailable\r"
        echo -e "Content-Type: text/plain\r"
        echo -e "Connection: close\r"
        echo -e "\r"
        echo "503 Service Unavailable - Failed to collect metrics"
        return
    fi
    
    # Calculate content length
    local content_length
    content_length=$(echo -n "$metrics" | wc -c)
    
    # Send HTTP response
    echo -e "HTTP/1.1 200 OK\r"
    echo -e "Content-Type: text/plain; version=0.0.4; charset=utf-8\r"
    echo -e "Content-Length: $content_length\r"
    echo -e "Connection: close\r"
    echo -e "\r"
    echo -n "$metrics"
    
    log "Served metrics (${content_length} bytes)"
}

# Function to serve health check endpoint
serve_health() {
    local status="OK"
    local http_code="200 OK"
    
    # Test if exporter can connect to Unbound
    if ! "$EXPORTER_SCRIPT" test >/dev/null 2>&1; then
        status="ERROR: Cannot connect to Unbound"
        http_code="503 Service Unavailable"
        log "Health check failed: Cannot connect to Unbound"
    else
        log "Health check passed"
    fi
    
    local response="Status: $status"
    local content_length
    content_length=$(echo -n "$response" | wc -c)
    
    echo -e "HTTP/1.1 $http_code\r"
    echo -e "Content-Type: text/plain\r"
    echo -e "Content-Length: $content_length\r"
    echo -e "Connection: close\r"
    echo -e "\r"
    echo -n "$response"
}

# Function to serve index page
serve_index() {
    local html='<!DOCTYPE html>
<html>
<head>
    <title>Unbound Prometheus Exporter</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        h1 { color: #333; }
        .endpoint { margin: 10px 0; }
        .endpoint a { text-decoration: none; color: #0066cc; }
        .endpoint a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <h1>Unbound Prometheus Exporter</h1>
    <p>This is a Prometheus exporter for Unbound DNS resolver statistics.</p>
    <h2>Endpoints:</h2>
    <div class="endpoint">
        <strong><a href="/metrics">/metrics</a></strong> - Prometheus metrics
    </div>
    <div class="endpoint">
        <strong><a href="/health">/health</a></strong> - Health check
    </div>
    <h2>Configuration:</h2>
    <ul>
        <li>Listen Address: '"$LISTEN_ADDRESS"'</li>
        <li>Listen Port: '"$LISTEN_PORT"'</li>
        <li>Exporter Script: '"$EXPORTER_SCRIPT"'</li>
    </ul>
</body>
</html>'
    
    local content_length
    content_length=$(echo -n "$html" | wc -c)
    
    echo -e "HTTP/1.1 200 OK\r"
    echo -e "Content-Type: text/html\r"
    echo -e "Content-Length: $content_length\r"
    echo -e "Connection: close\r"
    echo -e "\r"
    echo -n "$html"
    
    log "Served index page"
}

# Function to serve 404 responses
serve_404() {
    local path="$1"
    local response="404 Not Found: $path"
    local content_length
    content_length=$(echo -n "$response" | wc -c)
    
    echo -e "HTTP/1.1 404 Not Found\r"
    echo -e "Content-Type: text/plain\r"
    echo -e "Content-Length: $content_length\r"
    echo -e "Connection: close\r"
    echo -e "\r"
    echo -n "$response"
    
    log "404 Not Found: $path"
}

# Function to start the HTTP server
start_server() {
    log "Starting Unbound Prometheus Exporter HTTP Server"
    log "Listening on ${LISTEN_ADDRESS}:${LISTEN_PORT}"
    log "Exporter script: $EXPORTER_SCRIPT"
    log "Max connections: $MAX_CONNECTIONS"
    log "Timeout: ${TIMEOUT}s"
    
    # Check if exporter script exists and is executable
    if [[ ! -x "$EXPORTER_SCRIPT" ]]; then
        log "ERROR: Exporter script not found or not executable: $EXPORTER_SCRIPT"
        exit 1
    fi
    
    # Check if socat is available
    if ! command -v socat >/dev/null 2>&1; then
        log "ERROR: socat not found in PATH. Please install socat."
        exit 1
    fi
    
    # Test exporter script
    log "Testing exporter script..."
    if ! "$EXPORTER_SCRIPT" test; then
        log "WARNING: Exporter test failed, but continuing anyway"
    else
        log "Exporter test successful"
    fi
    
    # Create socat command
    local socat_cmd="socat"
    local listen_opts="TCP-LISTEN:${LISTEN_PORT},bind=${LISTEN_ADDRESS},reuseaddr,fork,max-children=${MAX_CONNECTIONS}"
    
    # Start the server
    log "Server starting..."
    exec socat "$listen_opts" SYSTEM:'timeout '"$TIMEOUT"' bash -c "$(declare -f handle_request serve_metrics serve_health serve_index serve_404 log); handle_request"'
}

# Function to stop the server (for systemd)
stop_server() {
    log "Stopping Unbound Prometheus Exporter HTTP Server"
    # Kill any socat processes listening on our port
    pkill -f "socat.*TCP-LISTEN:${LISTEN_PORT}" || true
}

# Signal handlers for graceful shutdown
trap 'stop_server; exit 0' SIGTERM SIGINT

# Handle command line arguments
case "${1:-start}" in
    "start"|"")
        start_server
        ;;
    "stop")
        stop_server
        ;;
    "restart")
        stop_server
        sleep 2
        start_server
        ;;
    "test")
        log "Testing HTTP server configuration..."
        if [[ ! -x "$EXPORTER_SCRIPT" ]]; then
            log "ERROR: Exporter script not found or not executable: $EXPORTER_SCRIPT"
            exit 1
        fi
        if ! command -v socat >/dev/null 2>&1; then
            log "ERROR: socat not found in PATH"
            exit 1
        fi
        log "Configuration test successful"
        ;;
    "version")
        echo "Unbound Exporter HTTP Server v1.0.0"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [start|stop|restart|test|version|help]"
        echo ""
        echo "Commands:"
        echo "  start    - Start the HTTP server (default)"
        echo "  stop     - Stop the HTTP server"
        echo "  restart  - Restart the HTTP server"
        echo "  test     - Test configuration"
        echo "  version  - Show server version"
        echo "  help     - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  LISTEN_PORT       - HTTP server port (default: 9167)"
        echo "  LISTEN_ADDRESS    - HTTP server bind address (default: 0.0.0.0)"
        echo "  EXPORTER_SCRIPT   - Path to exporter script (default: ./unbound-exporter.sh)"
        echo "  MAX_CONNECTIONS   - Maximum concurrent connections (default: 10)"
        echo "  TIMEOUT          - Request timeout in seconds (default: 30)"
        ;;
    *)
        log "ERROR: Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
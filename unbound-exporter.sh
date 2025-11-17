#!/bin/bash
#
# Unbound DNS Prometheus Exporter
# A bash-based exporter for Unbound DNS resolver statistics
#

# Set strict error handling
set -euo pipefail

# Source configuration if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Default configuration
UNBOUND_CONTROL="${UNBOUND_CONTROL:-unbound-control}"
UNBOUND_HOST="${UNBOUND_HOST:-127.0.0.1}"
UNBOUND_PORT="${UNBOUND_PORT:-8953}"
METRICS_PREFIX="${METRICS_PREFIX:-unbound}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

# Function to execute unbound-control commands
unbound_cmd() {
    local cmd="$1"
    if [[ -n "${UNBOUND_HOST}" && "${UNBOUND_HOST}" != "127.0.0.1" ]]; then
        timeout 10 "${UNBOUND_CONTROL}" -s "${UNBOUND_HOST}@${UNBOUND_PORT}" "$cmd" 2>/dev/null || echo "0"
    else
        timeout 10 "${UNBOUND_CONTROL}" "$cmd" 2>/dev/null || echo "0"
    fi
}

# Function to format Prometheus metric
format_metric() {
    local metric_name="$1"
    local value="$2"
    local labels="$3"
    local help="$4"
    local type="${5:-gauge}"
    
    echo "# HELP ${METRICS_PREFIX}_${metric_name} ${help}"
    echo "# TYPE ${METRICS_PREFIX}_${metric_name} ${type}"
    if [[ -n "$labels" ]]; then
        echo "${METRICS_PREFIX}_${metric_name}{${labels}} ${value}"
    else
        echo "${METRICS_PREFIX}_${metric_name} ${value}"
    fi
}

# Function to extract numeric value from unbound output
extract_value() {
    local line="$1"
    echo "$line" | grep -oE '[0-9]+(\.[0-9]+)?' | head -1 || echo "0"
}

# Function to get basic statistics
get_basic_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse and format basic statistics
    while IFS= read -r line; do
        case "$line" in
            *"total.num.queries="*)
                local value
                value=$(extract_value "$line")
                format_metric "queries_total" "$value" "" "Total number of queries" "counter"
                ;;
            *"total.num.cachehits="*)
                local value
                value=$(extract_value "$line")
                format_metric "cache_hits_total" "$value" "" "Total number of cache hits" "counter"
                ;;
            *"total.num.cachemiss="*)
                local value
                value=$(extract_value "$line")
                format_metric "cache_miss_total" "$value" "" "Total number of cache misses" "counter"
                ;;
            *"total.num.prefetch="*)
                local value
                value=$(extract_value "$line")
                format_metric "prefetch_total" "$value" "" "Total number of prefetches" "counter"
                ;;
            *"total.num.recursivereplies="*)
                local value
                value=$(extract_value "$line")
                format_metric "recursive_replies_total" "$value" "" "Total number of recursive replies" "counter"
                ;;
            *"total.requestlist.avg="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_avg" "$value" "" "Average number of requests in the request list"
                ;;
            *"total.requestlist.max="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_max" "$value" "" "Maximum number of requests in the request list"
                ;;
            *"total.requestlist.overwritten="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_overwritten_total" "$value" "" "Total number of overwritten requests" "counter"
                ;;
            *"total.requestlist.exceeded="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_exceeded_total" "$value" "" "Total number of exceeded requests" "counter"
                ;;
            *"total.requestlist.current.all="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_current" "$value" "" "Current number of requests in the request list"
                ;;
            *"total.requestlist.current.user="*)
                local value
                value=$(extract_value "$line")
                format_metric "request_list_current_user" "$value" "" "Current number of user requests in the request list"
                ;;
            *"total.num.queries_ip_ratelimited="*)
                local value
                value=$(extract_value "$line")
                format_metric "queries_ip_ratelimited_total" "$value" "" "Total number of IP rate limited queries" "counter"
                ;;
            *"total.num.zero_ttl="*)
                local value
                value=$(extract_value "$line")
                format_metric "zero_ttl_total" "$value" "" "Total number of zero TTL responses" "counter"
                ;;
            *"total.recursion.time.avg="*)
                local value
                value=$(extract_value "$line")
                format_metric "recursion_time_avg_seconds" "$value" "" "Average recursion time in seconds"
                ;;
            *"total.recursion.time.median="*)
                local value
                value=$(extract_value "$line")
                format_metric "recursion_time_median_seconds" "$value" "" "Median recursion time in seconds"
                ;;
            *"total.tcpusage="*)
                local value
                value=$(extract_value "$line")
                format_metric "tcp_usage" "$value" "" "TCP usage"
                ;;
        esac
    done <<< "$stats"
}

# Function to get query type statistics
get_query_type_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse query types
    while IFS= read -r line; do
        if [[ "$line" =~ ^num\.query\.type\.([^=]+)=(.+)$ ]]; then
            local qtype="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "queries_by_type_total" "$value" "type=\"$qtype\"" "Total queries by type" "counter"
        fi
    done <<< "$stats"
}

# Function to get query class statistics
get_query_class_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse query classes
    while IFS= read -r line; do
        if [[ "$line" =~ ^num\.query\.class\.([^=]+)=(.+)$ ]]; then
            local qclass="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "queries_by_class_total" "$value" "class=\"$qclass\"" "Total queries by class" "counter"
        fi
    done <<< "$stats"
}

# Function to get answer rcode statistics
get_rcode_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse answer rcodes
    while IFS= read -r line; do
        if [[ "$line" =~ ^num\.answer\.rcode\.([^=]+)=(.+)$ ]]; then
            local rcode="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "answers_by_rcode_total" "$value" "rcode=\"$rcode\"" "Total answers by rcode" "counter"
        fi
    done <<< "$stats"
}

# Function to get histogram statistics
get_histogram_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse histograms
    while IFS= read -r line; do
        if [[ "$line" =~ ^histogram\.([^.]+)\.([^=]+)=(.+)$ ]]; then
            local metric="${BASH_REMATCH[1]}"
            local bucket="${BASH_REMATCH[2]}"
            local value="${BASH_REMATCH[3]}"
            
            case "$metric" in
                "query_time_us")
                    format_metric "query_duration_seconds_bucket" "$value" "le=\"$(echo "scale=6; $bucket / 1000000" | bc)\"" "Query duration histogram" "histogram"
                    ;;
            esac
        fi
    done <<< "$stats"
}

# Function to get memory statistics
get_memory_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse memory statistics
    while IFS= read -r line; do
        case "$line" in
            *"mem.cache.rrset="*)
                local value
                value=$(extract_value "$line")
                format_metric "memory_cache_rrset_bytes" "$value" "" "Memory used by RRset cache"
                ;;
            *"mem.cache.message="*)
                local value
                value=$(extract_value "$line")
                format_metric "memory_cache_message_bytes" "$value" "" "Memory used by message cache"
                ;;
            *"mem.mod.iterator="*)
                local value
                value=$(extract_value "$line")
                format_metric "memory_module_iterator_bytes" "$value" "" "Memory used by iterator module"
                ;;
            *"mem.mod.validator="*)
                local value
                value=$(extract_value "$line")
                format_metric "memory_module_validator_bytes" "$value" "" "Memory used by validator module"
                ;;
            *"mem.streamwait="*)
                local value
                value=$(extract_value "$line")
                format_metric "memory_streamwait_bytes" "$value" "" "Memory used by stream wait structures"
                ;;
        esac
    done <<< "$stats"
}

# Function to get thread statistics
get_thread_stats() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    
    # Parse thread statistics
    while IFS= read -r line; do
        if [[ "$line" =~ ^thread([0-9]+)\.num\.queries=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_queries_total" "$value" "thread=\"$thread_id\"" "Total queries per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.queries_ip_ratelimited=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_queries_ip_ratelimited_total" "$value" "thread=\"$thread_id\"" "Total IP rate limited queries per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.cachehits=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_cache_hits_total" "$value" "thread=\"$thread_id\"" "Total cache hits per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.cachemiss=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_cache_miss_total" "$value" "thread=\"$thread_id\"" "Total cache misses per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.prefetch=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_prefetch_total" "$value" "thread=\"$thread_id\"" "Total prefetches per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.zero_ttl=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_zero_ttl_total" "$value" "thread=\"$thread_id\"" "Total zero TTL responses per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.num\.recursivereplies=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_recursive_replies_total" "$value" "thread=\"$thread_id\"" "Total recursive replies per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.avg=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_avg" "$value" "thread=\"$thread_id\"" "Average request list size per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.max=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_max" "$value" "thread=\"$thread_id\"" "Maximum request list size per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.overwritten=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_overwritten_total" "$value" "thread=\"$thread_id\"" "Total overwritten requests per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.exceeded=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_exceeded_total" "$value" "thread=\"$thread_id\"" "Total exceeded requests per thread" "counter"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.current\.all=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_current_all" "$value" "thread=\"$thread_id\"" "Current requests in list (all) per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.requestlist\.current\.user=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_request_list_current_user" "$value" "thread=\"$thread_id\"" "Current requests in list (user) per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.recursion\.time\.avg=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_recursion_time_avg_seconds" "$value" "thread=\"$thread_id\"" "Average recursion time per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.recursion\.time\.median=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_recursion_time_median_seconds" "$value" "thread=\"$thread_id\"" "Median recursion time per thread"
        elif [[ "$line" =~ ^thread([0-9]+)\.tcpusage=(.+)$ ]]; then
            local thread_id="${BASH_REMATCH[1]}"
            local value="${BASH_REMATCH[2]}"
            format_metric "thread_tcp_usage" "$value" "thread=\"$thread_id\"" "TCP usage per thread"
        fi
    done <<< "$stats"
}

# Function to get uptime
get_uptime() {
    local stats
    stats=$(unbound_cmd "stats_noreset")
    local uptime_seconds
    uptime_seconds=$(echo "$stats" | grep "^time\.up=" | cut -d'=' -f2 | cut -d'.' -f1 || echo "0")
    format_metric "uptime_seconds" "$uptime_seconds" "" "Unbound uptime in seconds" "counter"
}

# Function to get version and status info
get_version_info() {
    local status_output
    status_output=$(unbound_cmd "status" 2>/dev/null || echo "version: unknown")
    
    # Extract version number
    local version
    version=$(echo "$status_output" | grep "^version:" | cut -d' ' -f2 || echo "unknown")
    
    # Extract verbosity level
    local verbosity
    verbosity=$(echo "$status_output" | grep "^verbosity:" | cut -d' ' -f2 || echo "0")
    
    # Extract number of threads
    local threads
    threads=$(echo "$status_output" | grep "^threads:" | cut -d' ' -f2 || echo "1")
    
    # Extract modules info
    local modules
    modules=$(echo "$status_output" | grep "^modules:" | cut -d' ' -f2 || echo "0")
    
    # Output metrics
    format_metric "info" "1" "version=\"$version\"" "Unbound version information"
    format_metric "verbosity_level" "$verbosity" "" "Unbound verbosity level"
    format_metric "threads_configured" "$threads" "" "Number of configured threads"
    format_metric "modules_count" "$modules" "" "Number of loaded modules"
}

# Main function to collect and output all metrics
collect_metrics() {
    # Check if unbound-control is available
    if ! command -v "${UNBOUND_CONTROL}" >/dev/null 2>&1; then
        log "ERROR: ${UNBOUND_CONTROL} not found in PATH"
        exit 1
    fi

    # Test connection to unbound
    if ! unbound_cmd "status" >/dev/null 2>&1; then
        log "ERROR: Cannot connect to Unbound. Check if Unbound is running and control interface is enabled."
        exit 1
    fi

    # Output metrics header
    echo "# Unbound DNS Resolver Metrics"
    echo "# Generated at $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    echo ""

    # Collect all metrics
    get_version_info
    echo ""
    get_uptime
    echo ""
    get_basic_stats
    echo ""
    get_query_type_stats
    echo ""
    get_query_class_stats
    echo ""
    get_rcode_stats
    echo ""
    get_memory_stats
    echo ""
    get_thread_stats
    echo ""
    get_histogram_stats
}

# Handle command line arguments
case "${1:-collect}" in
    "collect"|"metrics"|"")
        collect_metrics
        ;;
    "test")
        log "Testing connection to Unbound..."
        if unbound_cmd "status" >/dev/null 2>&1; then
            log "SUCCESS: Connected to Unbound"
            exit 0
        else
            log "ERROR: Cannot connect to Unbound"
            exit 1
        fi
        ;;
    "version")
        echo "Unbound Exporter v1.0.0"
        ;;
    "help"|"-h"|"--help")
        echo "Usage: $0 [collect|test|version|help]"
        echo ""
        echo "Commands:"
        echo "  collect  - Collect and output Prometheus metrics (default)"
        echo "  test     - Test connection to Unbound"
        echo "  version  - Show exporter version"
        echo "  help     - Show this help message"
        echo ""
        echo "Environment variables:"
        echo "  UNBOUND_CONTROL - Path to unbound-control binary (default: unbound-control)"
        echo "  UNBOUND_HOST    - Unbound host (default: 127.0.0.1)"
        echo "  UNBOUND_PORT    - Unbound control port (default: 8953)"
        echo "  METRICS_PREFIX  - Metrics prefix (default: unbound)"
        ;;
    *)
        log "ERROR: Unknown command: $1"
        echo "Use '$0 help' for usage information"
        exit 1
        ;;
esac
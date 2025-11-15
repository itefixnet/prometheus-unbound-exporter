# Unbound Prometheus Exporter

A lightweight, bash-based Prometheus exporter for Unbound DNS resolver statistics. This exporter uses only bash and socat to provide comprehensive DNS metrics for monitoring with Prometheus and Grafana.

## Features

- **Pure Bash Implementation**: No external dependencies except `socat` and `unbound-control`
- **Comprehensive Metrics**: Exports all major Unbound statistics including:
  - Query rates and types
  - Cache hit/miss ratios
  - Memory usage by component
  - Thread statistics
  - Response codes distribution
  - Request list statistics
- **HTTP Server**: Built-in HTTP server using socat for serving metrics
- **Systemd Integration**: Ready-to-use systemd service file
- **Grafana Dashboard**: Pre-built comprehensive dashboard

## Quick Start

### Prerequisites

- Unbound DNS resolver with control interface enabled
- `socat` package installed
- `unbound-control` accessible
- Prometheus server for scraping metrics

### Basic Installation

1. Clone the repository:
```bash
git clone https://github.com/itefixnet/prometheus-unbound-exporter.git
cd prometheus-unbound-exporter
```

2. Test the exporter:
```bash
./unbound-exporter.sh test
```

3. Start the HTTP server:
```bash
./http-server.sh start
```

4. Access metrics at `http://localhost:9167/metrics`

### System Installation

For production deployment, install as a system service:

```bash
# Create user and directories
sudo useradd -r -s /bin/false unbound-exporter
sudo mkdir -p /opt/unbound-exporter

# Copy files
sudo cp *.sh /opt/unbound-exporter/
sudo cp config.sh /opt/unbound-exporter/
sudo cp unbound-exporter.conf /opt/unbound-exporter/
sudo cp unbound-exporter.service /etc/systemd/system/

# Set permissions
sudo chown -R unbound-exporter:unbound-exporter /opt/unbound-exporter
sudo chmod +x /opt/unbound-exporter/*.sh

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable unbound-exporter
sudo systemctl start unbound-exporter
```

## Configuration

### Environment Variables

The exporter can be configured using environment variables or configuration files:

| Variable | Default | Description |
|----------|---------|-------------|
| `UNBOUND_CONTROL` | `unbound-control` | Path to unbound-control binary |
| `UNBOUND_HOST` | `127.0.0.1` | Unbound server host |
| `UNBOUND_PORT` | `8953` | Unbound control port |
| `LISTEN_PORT` | `9167` | HTTP server port |
| `LISTEN_ADDRESS` | `0.0.0.0` | HTTP server bind address |
| `METRICS_PREFIX` | `unbound` | Prometheus metrics prefix |
| `MAX_CONNECTIONS` | `10` | Maximum concurrent HTTP connections |
| `TIMEOUT` | `30` | Request timeout in seconds |

### Configuration Files

1. **`config.sh`**: Shell configuration file (sourced by scripts)
2. **`unbound-exporter.conf`**: Systemd environment file (same directory as scripts)

### Unbound Configuration

Ensure Unbound has the control interface enabled in `/etc/unbound/unbound.conf`:

```
server:
    # ... other settings ...

remote-control:
    control-enable: yes
    control-interface: 127.0.0.1
    control-port: 8953
    control-use-cert: no
```

Restart Unbound after configuration changes:
```bash
sudo systemctl restart unbound
```

## Metrics

The exporter provides the following Prometheus metrics:

### Basic Statistics
- `unbound_queries_total` - Total number of queries
- `unbound_cache_hits_total` - Total cache hits
- `unbound_cache_miss_total` - Total cache misses
- `unbound_prefetch_total` - Total prefetches
- `unbound_recursive_replies_total` - Total recursive replies
- `unbound_uptime_seconds` - Unbound uptime

### Request List Statistics
- `unbound_request_list_current` - Current requests in queue
- `unbound_request_list_avg` - Average request list size
- `unbound_request_list_max` - Maximum request list size
- `unbound_request_list_overwritten_total` - Overwritten requests
- `unbound_request_list_exceeded_total` - Exceeded requests

### Memory Usage
- `unbound_memory_cache_rrset_bytes` - RRset cache memory
- `unbound_memory_cache_message_bytes` - Message cache memory
- `unbound_memory_module_iterator_bytes` - Iterator module memory
- `unbound_memory_module_validator_bytes` - Validator module memory
- `unbound_memory_streamwait_bytes` - Stream wait memory

### Query Statistics by Labels
- `unbound_queries_by_type_total{type="A|AAAA|PTR|..."}` - Queries by type
- `unbound_queries_by_class_total{class="IN|CH|..."}` - Queries by class
- `unbound_answers_by_rcode_total{rcode="NOERROR|NXDOMAIN|..."}` - Answers by response code

### Thread Statistics
- `unbound_thread_queries_total{thread="0|1|2|..."}` - Queries per thread
- `unbound_thread_cache_hits_total{thread="0|1|2|..."}` - Cache hits per thread
- `unbound_thread_cache_miss_total{thread="0|1|2|..."}` - Cache misses per thread

### Version Information
- `unbound_info{version="1.x.x"}` - Unbound version info

## Usage Examples

### Manual Testing

```bash
# Test connection to Unbound
./unbound-exporter.sh test

# Collect metrics once
./unbound-exporter.sh collect

# Start HTTP server manually
./http-server.sh start

# Test HTTP endpoints
curl http://localhost:9167/metrics
curl http://localhost:9167/health
curl http://localhost:9167/
```

### Prometheus Configuration

Add this job to your `prometheus.yml`:

```yaml
scrape_configs:
  - job_name: 'unbound-exporter'
    static_configs:
      - targets: ['localhost:9167']
    scrape_interval: 30s
    metrics_path: /metrics
```

### Grafana Dashboard

Import the provided `grafana-dashboard.json` file into your Grafana instance:

1. Go to Dashboards → Import
2. Upload `grafana-dashboard.json`
3. Select your Prometheus datasource
4. Save the dashboard

The dashboard includes:
- Uptime monitoring
- Query rate trends
- Cache hit rate percentage
- Query type distribution
- Response code distribution
- Memory usage by component
- Thread performance
- Request queue statistics

## Troubleshooting

### Common Issues

1. **Permission Denied**:
   - Ensure scripts are executable: `chmod +x *.sh`
   - Check unbound-exporter user permissions

2. **Cannot Connect to Unbound**:
   - Verify Unbound is running: `systemctl status unbound`
   - Check control interface configuration
   - Test manually: `unbound-control status`

3. **Port Already in Use**:
   - Change `LISTEN_PORT` in configuration
   - Check for other services: `netstat -tlnp | grep 9167`

4. **Missing Dependencies**:
   ```bash
   # Install socat (Ubuntu/Debian)
   sudo apt-get install socat
   
   # Install socat (CentOS/RHEL)
   sudo yum install socat
   ```

### Logging

- Service logs: `journalctl -u unbound-exporter -f`
- Manual logs: Scripts output to stderr

### Performance Tuning

For high-traffic DNS servers:
- Increase `MAX_CONNECTIONS`
- Adjust `TIMEOUT` value
- Monitor system resources
- Consider running multiple exporter instances

## Development

### Testing

```bash
# Run basic tests
./unbound-exporter.sh test
./http-server.sh test

# Test with different configurations
UNBOUND_HOST=remote-server ./unbound-exporter.sh test
```

### Contributing

1. Fork the repository
2. Create a feature branch
3. Test thoroughly
4. Submit a pull request

### License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- GitHub Issues: [https://github.com/itefixnet/prometheus-unbound-exporter/issues](https://github.com/itefixnet/prometheus-unbound-exporter/issues)
- Documentation: This README and inline script comments

## Alternatives

This exporter focuses on simplicity and minimal dependencies. For more advanced features, consider:
- [unbound_exporter](https://github.com/letsencrypt/unbound_exporter) (Go-based)
- Custom telegraf configurations
- SNMP-based monitoring (if Unbound supports it)
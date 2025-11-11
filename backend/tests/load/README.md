# Load Testing Suite

Performance and load testing for TelePrompt Pro API using K6.

## Prerequisites

### Install K6

```bash
# macOS
brew install k6

# Ubuntu/Debian
sudo gpg -k
sudo gpg --no-default-keyring --keyring /usr/share/keyrings/k6-archive-keyring.gpg --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys C5AD17C747E3415A3642D57D77C6C491D6AC1D69
echo "deb [signed-by=/usr/share/keyrings/k6-archive-keyring.gpg] https://dl.k6.io/deb stable main" | sudo tee /etc/apt/sources.list.d/k6.list
sudo apt-get update
sudo apt-get install k6

# Windows
choco install k6

# Or download binary
# https://k6.io/docs/get-started/installation/
```

## Running Tests

### Basic Run

```bash
cd backend/tests/load
k6 run scripts-api.js
```

### Custom Configuration

```bash
# 100 virtual users for 5 minutes
k6 run --vus 100 --duration 5m scripts-api.js

# Custom API URL
k6 run -e API_URL=https://api.teleprompt.pro scripts-api.js

# Save results to JSON
k6 run scripts-api.js --out json=results.json

# Real-time monitoring with InfluxDB
k6 run --out influxdb=http://localhost:8086/k6 scripts-api.js
```

### Available Tests

1. **scripts-api.js** - Scripts CRUD operations
2. **auth-api.js** - Authentication flows (create separately)
3. **websocket-stress.js** - WebSocket connection stress test (create separately)
4. **full-load.js** - Complete user journey (create separately)

## Test Scenarios

### scripts-api.js

**Load Pattern:**
- Ramp up: 1min to 10 users
- Scale up: 3min to 50 users
- Sustained load: 5min at 100 users
- Scale down: 2min to 50 users
- Ramp down: 1min to 0 users

**Tests:**
- Create script (< 1s)
- Fetch scripts list (< 500ms)
- Update script (< 800ms)
- Get single script (< 300ms)

**Thresholds:**
- 95% of requests < 500ms
- Error rate < 5%
- Custom error rate < 10%

## Interpreting Results

### K6 Output

```
     ✓ create status is 201
     ✓ create has script id
     ✓ create duration < 1s
     ✓ fetch status is 200
     ✓ fetch has array
     ✓ fetch duration < 500ms

     checks.........................: 95.23% ✓ 57234  ✗ 2876
     data_received..................: 156 MB 2.6 MB/s
     data_sent......................: 45 MB  750 kB/s
     errors.........................: 5.02%  ✓ 2876   ✗ 54358
     http_req_blocked...............: avg=1.2ms   min=0s   med=1ms   max=234ms   p(90)=2ms    p(95)=3ms
     http_req_connecting............: avg=0.8ms   min=0s   med=0.7ms max=180ms   p(90)=1.4ms  p(95)=1.8ms
     http_req_duration..............: avg=245ms   min=12ms med=198ms max=1.2s    p(90)=412ms  p(95)=532ms
       { expected_response:true }...: avg=238ms   min=12ms med=192ms max=987ms   p(90)=398ms  p(95)=512ms
     http_req_failed................: 5.02%  ✓ 2876   ✗ 54358
     http_req_receiving.............: avg=0.4ms   min=0s   med=0.2ms max=45ms    p(90)=0.8ms  p(95)=1.2ms
     http_req_sending...............: avg=0.1ms   min=0s   med=0.1ms max=23ms    p(90)=0.2ms  p(95)=0.3ms
     http_req_tls_handshaking.......: avg=0s      min=0s   med=0s    max=0s      p(90)=0s     p(95)=0s
     http_req_waiting...............: avg=244ms   min=12ms med=197ms max=1.2s    p(90)=411ms  p(95)=531ms
     http_reqs......................: 57234  953.9/s
     iteration_duration.............: avg=3.2s    min=2.1s med=3.1s  max=5.4s    p(90)=3.8s   p(95)=4.2s
     iterations.....................: 14234  237.2/s
     vus............................: 100    min=0    max=100
     vus_max........................: 100    min=100  max=100
```

### Key Metrics

- **http_req_duration**: Response time (p95 should be < 500ms)
- **http_req_failed**: Error rate (should be < 5%)
- **checks**: Test assertions passed (should be > 95%)
- **http_reqs**: Requests per second throughput
- **iteration_duration**: Full test iteration time

### Performance Goals

| Metric | Target | Acceptable | Poor |
|--------|--------|------------|------|
| p95 Response Time | < 300ms | < 500ms | > 1s |
| Error Rate | < 1% | < 5% | > 10% |
| Requests/sec | > 500 | > 200 | < 100 |
| Checks Pass Rate | > 99% | > 95% | < 90% |

## Cloud Load Testing

### K6 Cloud

```bash
# Login to K6 Cloud
k6 login cloud

# Run test on K6 Cloud
k6 cloud scripts-api.js

# Run distributed test
k6 cloud --vus 1000 --duration 10m scripts-api.js
```

### Grafana Dashboard

1. Setup InfluxDB:
```bash
docker run -d -p 8086:8086 \
  --name influxdb \
  -e INFLUXDB_DB=k6 \
  influxdb:1.8
```

2. Run test with InfluxDB output:
```bash
k6 run --out influxdb=http://localhost:8086/k6 scripts-api.js
```

3. View in Grafana:
- Import K6 dashboard (ID: 2587)
- Connect to InfluxDB datasource
- View real-time metrics

## Debugging Performance Issues

### High Response Times

1. Check database query performance:
```sql
-- PostgreSQL slow query log
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;
```

2. Check cache hit rate:
```bash
redis-cli info stats | grep keyspace_hits
```

3. Profile API endpoints:
```bash
# Enable Node.js profiling
NODE_ENV=production node --prof server.js

# Analyze profile
node --prof-process isolate-*.log > processed.txt
```

### High Error Rates

1. Check application logs:
```bash
tail -f backend/logs/app.log | grep ERROR
```

2. Monitor error types:
```bash
# Group errors by type
cat results.json | jq '.metrics.errors' | sort | uniq -c
```

3. Check database connections:
```sql
SELECT count(*) FROM pg_stat_activity;
```

## Continuous Performance Testing

### GitHub Actions

```yaml
name: Performance Tests

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM
  workflow_dispatch:

jobs:
  load-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Install K6
        run: |
          sudo apt-get update
          sudo apt-get install k6

      - name: Run load test
        run: |
          cd backend/tests/load
          k6 run scripts-api.js --out json=results.json

      - name: Check thresholds
        run: |
          # Parse results and fail if thresholds not met
          cat results.json | jq '.metrics.http_req_failed.values.rate'

      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: load-test-results
          path: backend/tests/load/results.json
```

## Best Practices

1. **Start small** - Begin with low load and gradually increase
2. **Test production-like data** - Use realistic payload sizes
3. **Monitor resources** - Watch CPU, memory, database connections
4. **Test regularly** - Catch performance regressions early
5. **Set thresholds** - Define acceptable performance metrics
6. **Document baselines** - Track performance over time
7. **Test edge cases** - Large payloads, concurrent users, long-running requests

## Troubleshooting

### Connection Refused

**Error:** `request failed: dial tcp connect: connection refused`

**Solution:** Ensure backend server is running:
```bash
cd backend/api-gateway
npm run dev
```

### Rate Limiting

**Error:** HTTP 429 errors

**Solution:** Adjust rate limits or use distributed load:
```javascript
export const options = {
  scenarios: {
    distributed_load: {
      executor: 'ramping-arrival-rate',
      startRate: 10,
      timeUnit: '1s',
      preAllocatedVUs: 50,
      maxVUs: 100,
      stages: [
        { target: 50, duration: '5m' },
      ],
    },
  },
};
```

### Database Connection Pool Exhausted

**Error:** `remaining connection slots are reserved`

**Solution:** Increase PostgreSQL max_connections:
```sql
ALTER SYSTEM SET max_connections = 200;
SELECT pg_reload_conf();
```

## Additional Resources

- [K6 Documentation](https://k6.io/docs/)
- [K6 Examples](https://k6.io/docs/examples/)
- [Performance Testing Best Practices](https://k6.io/docs/testing-guides/api-load-testing/)
- [K6 Cloud](https://k6.io/cloud/)

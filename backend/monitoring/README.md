# Monitoring & Alerting Setup

Comprehensive monitoring and alerting for TelePrompt Pro backend services.

## Overview

Multi-layer monitoring strategy:
- **Application Monitoring**: Errors, performance, user actions
- **Infrastructure Monitoring**: Server resources, database, cache
- **Business Metrics**: User signups, subscriptions, revenue
- **Security Monitoring**: Failed logins, suspicious activities

## Tools

### Sentry - Error Tracking

**Setup:**

```bash
npm install @sentry/node @sentry/tracing
```

**Configuration** (`backend/api-gateway/src/sentry.ts`):

```typescript
import * as Sentry from "@sentry/node";
import * as Tracing from "@sentry/tracing";
import { Express } from "express";

export function initializeSentry(app: Express) {
  Sentry.init({
    dsn: process.env.SENTRY_DSN,
    environment: process.env.NODE_ENV,
    tracesSampleRate: 0.1,
    integrations: [
      new Sentry.Integrations.Http({ tracing: true }),
      new Tracing.Integrations.Express({ app }),
    ],
  });

  // Request handler must be first middleware
  app.use(Sentry.Handlers.requestHandler());
  app.use(Sentry.Handlers.tracingHandler());
}

export function setupSentryErrorHandler(app: Express) {
  // Error handler must be before other error middleware
  app.use(Sentry.Handlers.errorHandler());
}
```

**Usage:**

```typescript
// Manual error capture
Sentry.captureException(error);

// Add context
Sentry.setUser({ id: userId, email });
Sentry.setTag("feature", "scripts");
Sentry.addBreadcrumb({
  category: "auth",
  message: "User logged in",
  level: "info",
});
```

### Prometheus - Metrics Collection

**Setup:**

```bash
npm install prom-client
```

**Configuration:**

```typescript
import promClient from 'prom-client';

// Create metrics
const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10],
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code'],
});

const activeConnections = new promClient.Gauge({
  name: 'websocket_active_connections',
  help: 'Number of active WebSocket connections',
});

// Middleware
export function metricsMiddleware(req, res, next) {
  const start = Date.now();

  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration.labels(req.method, req.route?.path || req.path, res.statusCode).observe(duration);
    httpRequestsTotal.labels(req.method, req.route?.path || req.path, res.statusCode).inc();
  });

  next();
}

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', promClient.register.contentType);
  res.end(await promClient.register.metrics());
});
```

### Grafana - Visualization

**Docker Compose:**

```yaml
version: '3.8'

services:
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    ports:
      - "9090:9090"

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - "3001:3000"
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin

volumes:
  prometheus_data:
  grafana_data:
```

**Prometheus Config** (`prometheus.yml`):

```yaml
global:
  scrape_interval: 15s

scrape_configs:
  - job_name: 'api-gateway'
    static_configs:
      - targets: ['api-gateway:3000']

  - job_name: 'postgres'
    static_configs:
      - targets: ['postgres-exporter:9187']

  - job_name: 'redis'
    static_configs:
      - targets: ['redis-exporter:9121']
```

**Grafana Dashboards:**
- Node.js Application Metrics (ID: 11159)
- PostgreSQL Overview (ID: 9628)
- Redis Dashboard (ID: 11835)

### Uptime Monitoring

**UptimeRobot or Better Uptime:**

Monitor endpoints:
- https://api.teleprompt.pro/api/health
- https://teleprompt.pro
- https://admin.teleprompt.pro

Alert on:
- HTTP 5xx errors
- Response time > 5s
- Downtime > 1 minute

### Log Aggregation

**Options:**

1. **ELK Stack** (Elasticsearch, Logstash, Kibana)
2. **Loki + Grafana**
3. **CloudWatch Logs** (AWS)
4. **Datadog**

**Structured Logging:**

```typescript
import winston from 'winston';

const logger = winston.createLogger({
  level: 'info',
  format: winston.format.json(),
  defaultMeta: { service: 'api-gateway' },
  transports: [
    new winston.transports.File({ filename: 'error.log', level: 'error' }),
    new winston.transports.File({ filename: 'combined.log' }),
  ],
});

// Usage
logger.info('User signed in', { userId, email });
logger.error('Database query failed', { error, query });
```

## Alerting

### Alert Rules

**Critical Alerts** (PagerDuty/Slack immediately):
- API error rate > 5%
- Database connection pool exhausted
- Redis unavailable
- Disk usage > 90%
- Memory usage > 90%
- Response time p95 > 2s

**Warning Alerts** (Email/Slack):
- API error rate > 2%
- Cache hit rate < 50%
- Response time p95 > 1s
- Failed login attempts > 10 in 5 minutes
- Subscription payment failures

**Info Alerts** (Email daily):
- Daily active users
- New signups
- Revenue summary
- Top errors by count

### Alertmanager Configuration

```yaml
global:
  slack_api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'

route:
  receiver: 'slack-notifications'
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  routes:
    - match:
        severity: critical
      receiver: 'pagerduty'
    - match:
        severity: warning
      receiver: 'slack-notifications'

receivers:
  - name: 'slack-notifications'
    slack_configs:
      - channel: '#alerts'
        title: 'Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'pagerduty'
    pagerduty_configs:
      - service_key: 'YOUR_PAGERDUTY_KEY'
```

## Health Checks

**Comprehensive Health Endpoint:**

```typescript
app.get('/api/health', async (req, res) => {
  const health = {
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    version: process.env.npm_package_version,
    services: {
      database: 'unknown',
      redis: 'unknown',
      websocket: 'unknown',
    },
  };

  // Check database
  try {
    await prisma.$queryRaw`SELECT 1`;
    health.services.database = 'healthy';
  } catch (error) {
    health.services.database = 'unhealthy';
    health.status = 'degraded';
  }

  // Check Redis
  try {
    await redis.ping();
    health.services.redis = 'healthy';
  } catch (error) {
    health.services.redis = 'unhealthy';
    health.status = 'degraded';
  }

  // Check WebSocket
  health.services.websocket = io.engine.clientsCount > 0 ? 'active' : 'idle';

  res.status(health.status === 'healthy' ? 200 : 503).json(health);
});
```

## Business Metrics Dashboard

**Custom Metrics:**

```typescript
// Track business events
const signupsTotal = new promClient.Counter({
  name: 'signups_total',
  help: 'Total user signups',
  labelNames: ['source'],
});

const subscriptionsActive = new promClient.Gauge({
  name: 'subscriptions_active',
  help: 'Active subscriptions by tier',
  labelNames: ['tier'],
});

const revenueTotal = new promClient.Counter({
  name: 'revenue_total_cents',
  help: 'Total revenue in cents',
  labelNames: ['tier'],
});

// Update metrics
signupsTotal.labels('email').inc();
subscriptionsActive.labels('professional').set(150);
revenueTotal.labels('professional').inc(2999); // $29.99
```

## Performance Monitoring

**APM (Application Performance Monitoring):**

Options:
- New Relic
- Datadog APM
- Elastic APM
- AppDynamics

**Key Metrics:**
- Request throughput (req/s)
- Response time (p50, p95, p99)
- Error rate (%)
- Apdex score
- Database query time
- External API latency

## Security Monitoring

**Track Security Events:**

```typescript
// Failed login attempts
const failedLogins = new promClient.Counter({
  name: 'failed_logins_total',
  help: 'Failed login attempts',
  labelNames: ['reason'],
});

// Suspicious activities
const suspiciousActivities = new promClient.Counter({
  name: 'suspicious_activities_total',
  help: 'Suspicious user activities',
  labelNames: ['type'],
});

// Alert on patterns
if (failedLogins > 10 in 5 minutes from same IP) {
  alert('Possible brute force attack');
}
```

## Runbooks

### High Error Rate

1. Check Sentry for error types
2. Review recent deployments
3. Check database health
4. Review application logs
5. Roll back if needed
6. Post-mortem after resolution

### Database Connection Issues

1. Check connection pool metrics
2. Review slow queries
3. Check database server resources
4. Restart app servers if needed
5. Scale database if needed

### High Response Time

1. Check APM transaction traces
2. Review database query performance
3. Check cache hit rate
4. Review API external calls
5. Scale horizontally if needed

## Cost Optimization

**Free Tier Options:**
- Sentry: 5K errors/month
- Grafana Cloud: Free tier available
- UptimeRobot: 50 monitors free
- Prometheus: Self-hosted

**Paid Services Budget:**
- Sentry Pro: $26/month
- Better Uptime: $20/month
- Datadog: ~$15/host/month
- New Relic: ~$99/month

Total: ~$160/month for comprehensive monitoring

## Getting Started

1. **Set up Sentry**
2. **Deploy Prometheus + Grafana**
3. **Configure uptime monitoring**
4. **Set up alerts**
5. **Create dashboards**
6. **Test alert notifications**
7. **Document runbooks**

## Resources

- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Sentry Documentation](https://docs.sentry.io/)
- [SRE Book - Google](https://sre.google/sre-book/table-of-contents/)

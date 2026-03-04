# Monitoring & Observability — Diaspora Equb DeFi Backend

This document covers the production monitoring strategy for the Diaspora Equb backend, event indexer, and on-chain components running on Creditcoin mainnet.

---

## 1. Sentry Error Tracking

`@sentry/node` is already listed in `package.json`. Initialize Sentry early in the application bootstrap:

```typescript
// main.ts — before NestFactory.create()
import * as Sentry from '@sentry/node';

Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV || 'production',
  tracesSampleRate: 0.2, // 20% of transactions for performance monitoring
  integrations: [
    Sentry.httpIntegration(),
  ],
});
```

### Key Sentry configuration

| Setting | Value | Reason |
|---|---|---|
| `environment` | `production` / `staging` | Filter issues by deploy target |
| `tracesSampleRate` | `0.1`–`0.3` | Balance performance insight vs. cost |
| `release` | `diaspora-equb@<git-sha>` | Map errors to source commits |
| `beforeSend` | Filter PII | Strip wallet addresses from breadcrumbs if required |

### Sentry alerts to configure

- **New Issue** — triggers on first occurrence of any unhandled exception.
- **Regression** — previously resolved issue re-surfaces.
- **High Volume** — same error >50 occurrences in 5 minutes.

---

## 2. Health Check Endpoints

The backend exposes three health endpoints (no authentication required):

| Endpoint | Purpose | Monitoring use |
|---|---|---|
| `GET /api/health` | Basic liveness — DB + RPC ping | Uptime monitor (UptimeRobot, Pingdom, etc.) |
| `GET /api/health/detailed` | Full status — DB, RPC, indexer, Redis, block lag | Grafana HTTP probe / incident dashboard |
| `GET /api/health/indexer` | Indexer-specific: running state, event count, per-contract block progress | Indexer lag alerting |

### Uptime monitoring setup

1. Point your uptime monitor (e.g. UptimeRobot free tier) at `https://your-domain/api/health`.
2. Set check interval to **1 minute**.
3. Alert via Slack / email / PagerDuty on 2 consecutive failures.
4. For deeper checks, poll `/api/health/detailed` and alert if `status !== "healthy"`.

---

## 3. Key Metrics to Watch

### Application metrics

| Metric | Source | Warning threshold |
|---|---|---|
| **API response time (p95)** | Sentry Performance / Nginx access log | > 500ms |
| **API error rate (5xx)** | Sentry / Nginx | > 5% of requests |
| **Request throughput** | Nginx access log | Sudden drop > 50% |
| **Active WebSocket connections** | Custom gauge in `EventsGateway` | Spike or drop > 3x |

### Indexer metrics

| Metric | Source | Warning threshold |
|---|---|---|
| **Block lag** (chain head − min indexed block) | `/api/health/detailed` → `chain.maxBlockLag` | > 100 blocks |
| **Indexed event count** | `/api/health/indexer` | Flatlines for > 10 minutes |
| **Indexer last error** | `/api/health/indexer` → `lastError` | Non-null |
| **Catch-up duration** | Application logs | > 5 minutes |

### Infrastructure metrics

| Metric | Source | Warning threshold |
|---|---|---|
| **DB connection pool** | TypeORM / pg_stat_activity | Active connections > 80% of pool |
| **DB query latency (p95)** | `/api/health/detailed` → `services.database.latencyMs` | > 100ms |
| **Redis memory usage** | `redis-cli INFO memory` | > 80% of maxmemory |
| **Redis connected clients** | `redis-cli INFO clients` | > 100 |
| **Container CPU / Memory** | Docker stats / cAdvisor | CPU > 80%, Memory > 85% |
| **Disk usage (Postgres volume)** | Node exporter / `df` | > 80% |

---

## 4. Grafana Dashboard Recommendations

Create a single "Diaspora Equb — Production" dashboard with the following panels:

### Row 1 — Overview

| Panel | Type | Query source |
|---|---|---|
| System status (healthy / degraded) | Stat | HTTP probe → `/api/health/detailed` → `status` |
| Uptime | Stat | Uptime monitor webhook |
| Active users (WebSocket connections) | Gauge | Application metric |

### Row 2 — API Performance

| Panel | Type |
|---|---|
| Request rate (req/s) | Time series (Nginx logs or Prometheus) |
| Response time distribution (p50, p95, p99) | Heatmap |
| Error rate (4xx vs 5xx) | Stacked bar |
| Top slow endpoints | Table |

### Row 3 — Indexer

| Panel | Type |
|---|---|
| Block lag per contract | Time series |
| Indexed events over time | Time series |
| Indexer status | Stat (up/down) |
| Last error | Log panel |

### Row 4 — Infrastructure

| Panel | Type |
|---|---|
| Postgres active connections | Gauge |
| Postgres query latency | Time series |
| Redis memory usage | Time series |
| Container CPU & memory | Time series (per service) |
| Disk usage | Gauge |

### Row 5 — On-Chain Activity

| Panel | Type |
|---|---|
| Pool creations per day | Bar chart |
| Contributions per day | Bar chart |
| Defaults triggered | Time series |
| Collateral slashed (CTC value) | Time series |

### Data source notes

- Use **Prometheus** with `node_exporter` and `postgres_exporter` for infrastructure.
- Use **Loki** for log aggregation (NestJS logs + Nginx access logs).
- Use the Grafana **JSON API** data source to query `/api/health/detailed` directly.

---

## 5. Alert Rules

### Critical (page immediately)

| Alert | Condition | Action |
|---|---|---|
| **Health check failure** | `/api/health` returns non-200 for 2+ checks | Investigate backend / DB / RPC |
| **Error rate spike** | 5xx rate > 5% over 5-minute window | Check Sentry, review recent deploy |
| **Database unreachable** | DB ping fails for 1 minute | Check Postgres container, connection pool |
| **RPC node down** | RPC ping fails for 2 minutes | Failover to backup RPC endpoint |

### Warning (Slack notification)

| Alert | Condition | Action |
|---|---|---|
| **Indexer lag** | Block lag > 100 blocks for 5 minutes | Check indexer logs, RPC rate limits |
| **Indexer stopped** | `isRunning === false` | Restart backend, check logs |
| **High API latency** | p95 response time > 1 second for 5 minutes | Profile slow queries, check DB |
| **Redis memory high** | Memory > 80% of limit | Review TTLs, increase limit |
| **Disk usage high** | Postgres volume > 80% | Run VACUUM, expand volume |
| **DB pool exhaustion** | Active connections > 80% of max | Increase pool size or investigate leaks |

### Info (daily digest)

| Alert | Condition |
|---|---|
| **New smart contract events** | Daily count of PoolCreated, DefaultTriggered |
| **Deployment detected** | New release tag or container restart |

---

## 6. On-Chain Monitoring

In addition to backend monitoring, watch these on-chain signals:

### Critical on-chain events

| Event | What to watch | Alert threshold |
|---|---|---|
| **Mass defaults** | `DefaultTriggered` events across multiple pools | > 5 defaults within 1 hour |
| **Large withdrawals** | Collateral withdrawal or token transfer | Single withdrawal > 10,000 CTC |
| **Contract upgrades** | UUPS `Upgraded` event on any proxy | Any occurrence — verify it was authorized |
| **Admin changes** | `OwnershipTransferred`, `MinterUpdated` | Any occurrence |
| **Governance proposals** | `ProposalCreated` with unusual parameters | Manual review within 24h |

### Monitoring approaches

1. **Blockscout alerts** — Use Creditcoin Blockscout (https://creditcoin.blockscout.com) to set up address watch notifications for all contract addresses.
2. **Indexer-based alerts** — The backend indexer already captures these events; add notification triggers for the critical patterns above.
3. **Multi-sig monitoring** — If using Gnosis Safe, enable Safe transaction notifications.

---

## 7. Backup Strategy

### PostgreSQL backups

```bash
# Automated daily backup via cron (add to host crontab)
# Runs at 02:00 UTC, retains 30 days
0 2 * * * docker exec equb-postgres pg_dump -U equb_prod diaspora_equb_prod | gzip > /backups/equb_$(date +\%Y\%m\%d).sql.gz && find /backups -name "equb_*.sql.gz" -mtime +30 -delete
```

**Verify backups regularly** — restore to a staging database monthly.

Recommended: Use managed PostgreSQL (e.g. AWS RDS, Supabase) which provides automated point-in-time recovery.

### Redis persistence

Redis is already configured with AOF (`--appendonly yes` in `docker-compose.yml`).

| Setting | Current | Recommended for production |
|---|---|---|
| `appendonly` | `yes` | Keep as-is |
| `appendfsync` | `everysec` (default) | Acceptable for cache workload |
| `maxmemory-policy` | `noeviction` (default) | Change to `allkeys-lru` if Redis is cache-only |

Since the CacheService is currently in-memory, Redis data is non-critical. When migrating to a real Redis-backed cache, ensure:
- AOF rewrite is scheduled (`auto-aof-rewrite-percentage 100`)
- Regular RDB snapshots as secondary backup

### Smart contract state

On-chain state is inherently backed up by the blockchain. The database is a cache that can be fully rebuilt by re-indexing from the deployment block using `indexer.reindex(deploymentBlock)`.

---

## 8. Log Management

### Structured logging

The NestJS `Logger` outputs structured logs. For production, configure JSON output:

```typescript
// main.ts
import { Logger } from '@nestjs/common';
app.useLogger(new Logger());
```

Set `LOG_LEVEL=warn` in production to reduce noise. Use `LOG_LEVEL=debug` only during incident investigation.

### Log aggregation

Ship container logs to a central log service:
- **Loki + Grafana** (self-hosted, pairs with Grafana dashboards)
- **Datadog / New Relic** (managed)
- **CloudWatch Logs** (if deployed on AWS)

### Key log patterns to alert on

| Pattern | Meaning |
|---|---|
| `Indexer startup failed` | Indexer cannot connect to RPC |
| `Catch-up poll failed` | Intermittent RPC or DB issue |
| `Failed to emit notification` | Notification pipeline broken |
| `Collateral slashed` | User defaulted, collateral taken |
| `duplicate key` | Possible re-indexing or race condition |

---

## 9. Incident Response Quick Reference

| Severity | Response time | Who |
|---|---|---|
| **P0** — Service down | 15 minutes | On-call engineer |
| **P1** — Degraded (indexer lag, high errors) | 1 hour | Backend team |
| **P2** — Warning (high latency, disk usage) | 8 hours | Backend team |
| **P3** — Informational | Next business day | Anyone |

### Common runbook entries

1. **Backend won't start** → Check DB connection, env vars, container logs.
2. **Indexer stuck** → Check RPC endpoint, look for `lastError` in `/api/health/indexer`. Force re-index with admin endpoint if needed.
3. **High block lag** → RPC might be rate-limiting. Switch to backup RPC. Increase `CATCH_UP_POLL_MS` temporarily.
4. **Database connection pool exhausted** → Restart backend. Check for long-running queries: `SELECT * FROM pg_stat_activity WHERE state = 'active';`
5. **Suspicious on-chain activity** → Pause frontend deposits. Contact security team. Do NOT interact with contracts until audit.

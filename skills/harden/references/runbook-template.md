# Runbook — {{service_name}}

> Template used by `/harden RUNBOOK-1`. Placeholders in `{{double-braces}}` are filled automatically from the codebase at generation time. Do NOT edit this template per project — fork it at the org level if you need different sections.

## Overview

**Service:** `{{service_name}}`
**Purpose:** {{one_line_purpose_from_readme}}
**Repo:** `{{git_remote_url}}`
**Primary language:** `{{stack_language}}`
**Framework:** `{{stack_framework}}`
**Runtime:** `{{runtime_version}}`

## Dependencies

Extracted from `{{env_example_path}}` and `{{compose_or_manifest_path}}`:

| Dependency | Type | Required? | How it's used |
|---|---|---|---|
| `{{db_kind}}` | database | yes | primary data store |
| `{{cache_kind}}` | cache | {{cache_required}} | session cache, rate-limit counters |
| `{{queue_kind}}` | queue | {{queue_required}} | background jobs |
| `{{external_apis}}` | external API | varies | see .env.example |

## Environment variables

All variables from `{{env_example_path}}`:

| Variable | Required | Purpose | Where set in prod |
|---|---|---|---|
{{env_vars_table}}

## Deployment

**Current deploy method:** `{{deploy_method}}` (auto-detected from `{{ci_config_path}}`)

**Build:**
```bash
{{build_commands}}
```

**Deploy:**
```bash
{{deploy_commands}}
```

**Rollback:**
```bash
{{rollback_commands}}
```

## Health checks

- **Liveness:** `{{liveness_url}}` — should return HTTP 200
- **Readiness:** `{{readiness_url}}` — should return HTTP 200 and include dependency status
- **Verify after deploy:** `curl -sf {{health_url}} | jq`

## Monitoring

- **Metrics endpoint:** `{{metrics_url}}`
- **Dashboard:** `{{dashboard_url_or_path}}`
- **Alerts:** `{{alerts_config_path}}`

## Common incidents

### I1. Service is down (liveness check failing)

**Symptoms:** `{{health_url}}` returns 5xx or connection refused. AlertManager `ServiceDown` firing.

**Diagnose:**
1. Check recent deploys: `{{git_log_cmd}}`
2. Check container status: `{{container_status_cmd}}`
3. Check logs: `{{logs_tail_cmd}}`
4. Check dependencies (DB, Redis reachable?)

**Resolve:**
- If last deploy was < 1h ago → **rollback** (see above).
- If dependency is down → page the dependency's owner.
- If resource exhaustion → restart the service, then investigate why.

### I2. High error rate

**Symptoms:** AlertManager `HighErrorRate` firing. Error rate > 5% for > 5 min.

**Diagnose:**
1. Check logs for the most common error: `{{logs_error_grep_cmd}}`
2. Correlate with recent deploys, dependency incidents, traffic spikes.
3. Check if errors are user-caused (4xx) or server-caused (5xx).

**Resolve:**
- 5xx spike after deploy → rollback.
- 5xx spike without deploy → check dependencies; consider scaling up.
- 4xx spike → check for a spammy client; consider rate limit tuning.

### I3. High latency

**Symptoms:** AlertManager `HighLatencyP95` firing. p95 > {{p95_slo}}ms for > 5 min.

**Diagnose:**
1. Check DB slow queries.
2. Check external API latency (third-party outage?).
3. Check CPU / memory saturation.

**Resolve:**
- DB slow query → add index, kill runaway query, scale DB.
- External API outage → failover to cache, circuit break, or degrade gracefully.
- Saturation → scale up replicas (HPA should handle automatically).

### I4. Database connection exhaustion

**Symptoms:** Errors like `too many connections`, `connection pool exhausted`.

**Diagnose:**
1. Check active connections: `{{db_active_connections_cmd}}`
2. Look for long-running transactions.

**Resolve:**
- Kill long-running transactions (coordinate with owner).
- Temporarily raise pool size in service config (requires restart).
- Long term: fix the query or add pooling (PgBouncer, RDS Proxy).

## Escalation

| Severity | First responder | Escalation after |
|---|---|---|
| SEV1 (service down, data loss risk) | oncall engineer | 15 min → tech lead → CTO |
| SEV2 (degraded, no data loss) | oncall engineer | 1 hour → tech lead |
| SEV3 (minor issue, can wait) | next business day | — |

**Contact list:** `{{contact_list_path}}`

## Rollback procedure

1. Identify the last known-good commit: `{{git_log_cmd}}`
2. Deploy it: see Deployment → Rollback above.
3. Verify health: `curl -sf {{health_url}}`
4. Post in `#incidents`: `rolled back {{service_name}} to <sha>, reason: <one-line>`
5. Open an issue for the rollback cause — do NOT re-deploy the bad version without a fix.

## Known limitations

{{known_limitations_from_readme_or_claude_md}}

## Last updated

{{updated_date}} by `/harden RUNBOOK-1` auto-generation. Edit in place for project-specific notes — `/harden` will not overwrite manually edited sections on re-run.

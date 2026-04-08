# Infrastructure-as-Code Generation Checklist (binary, deterministic)

> Applied by `/infra` to its own generated output, not to existing user code. Same tier semantics as `/review`.

## Tier 1: Critical (refuse to generate if any fails)

### TF-C1. Remote tfstate for prod
**Criterion:** every `envs/prod/backend.tf` uses a remote backend (S3, Spaces, GCS, Azure Blob, Terraform Cloud). `backend "local" {}` in prod → **refuse to generate**.
**Rationale:** local tfstate in prod means no locking, no backup, no audit — a single laptop crash can lose the entire cloud state.

### TF-C2. Pinned provider versions
**Criterion:** every `required_providers` block uses `~>` or exact version, never `>=` without upper bound, never missing `version`.
**Rationale:** unpinned providers break reproducibility and can introduce breaking changes on the next `terraform init`.

### TF-C3. No secrets in .tfvars committed to git
**Criterion:** generated `.gitignore` includes `*.tfvars` with an exception for `*.tfvars.example`. Generated `.tfvars.example` files contain only placeholders.

### TF-C4. Resource tagging
**Criterion:** every taggable resource in generated modules sets at least `environment`, `project`, `managed_by = "terraform"`.

### K8S-C1. Resources requests AND limits on every container
**Criterion:** every `container:` block in generated manifests has `resources.requests.cpu`, `resources.requests.memory`, `resources.limits.cpu`, `resources.limits.memory`. No `{}`.

### K8S-C2. Liveness and readiness probes
**Criterion:** every `container:` block has both `livenessProbe` and `readinessProbe`. Cross-references `/harden HC-3`.

### K8S-C3. No `:latest` tags in prod values
**Criterion:** `values-prod.yaml` image tag is a semver or digest, not `latest`.

### K8S-C4. Non-root containers
**Criterion:** every `securityContext` has `runAsNonRoot: true`. Containers that genuinely require root are rejected with a comment explaining why.

### SEC-C1. Outputs with sensitive values marked sensitive
**Criterion:** every Terraform output that contains a password, token, connection string, or key has `sensitive = true`.

---

## Tier 2: Important (warn but generate)

### TF-I1. Module variables have descriptions and types
**Criterion:** every `variable` block has both `description` and `type`.

### TF-I2. Outputs have descriptions
**Criterion:** every `output` block has `description`.

### K8S-I1. PodDisruptionBudget for > 1 replica services
**Criterion:** if replicas > 1 in values, `templates/pdb.yaml` is generated.

### K8S-I2. HorizontalPodAutoscaler
**Criterion:** `templates/hpa.yaml` is generated with sane min/max (min = replicas, max = 4x replicas by default).

### K8S-I3. NetworkPolicy default deny + explicit allows
**Criterion:** `templates/networkpolicy.yaml` starts with a default-deny and explicitly lists allowed ingress/egress.

### SEC-I1. Secret rotation documented
**Criterion:** README of the generated infra folder has a "Secret rotation" section listing each secret and its rotation method.

### SEC-I2. Least-privilege IAM
**Criterion:** generated IAM policies / role bindings list explicit actions, not `*`.

### README-I1. Generated README includes init/plan/apply commands
**Criterion:** `infra/README.md` exists and contains at least `terraform init`, `terraform plan -out=tfplan`, `terraform apply tfplan` for Terraform targets (or `helm install` for K8s targets).

---

## Tier 3: Nice-to-have

### TF-N1. Modules are parameterized for all sizes (dev/prod)
**Criterion:** module variables allow dev-size (small) and prod-size (bigger) via input variables without code duplication.

### K8S-N1. ServiceMonitor for Prometheus Operator
**Criterion:** if Prometheus Operator is detected in values, `templates/servicemonitor.yaml` is generated.

### DOC-N1. Architecture diagram
**Criterion:** generated README includes an ASCII or mermaid architecture diagram showing which module produces what.

---

## Refusal policy

`/infra` REFUSES to generate (not just warns) when:

1. Any TF-C1 violation — no local tfstate for prod, period.
2. Any K8S-C1 violation — no missing resource limits in K8s manifests.
3. User asks for a preset that is not in the supported list AND cannot describe their components clearly — return a clarification prompt.
4. User asks to embed a secret literal in `.tfvars` — refuse, explain TF-C3, offer to use `TF_VAR_*` env vars or a secrets backend instead.

## Default sizes (when user doesn't specify)

| Resource | Dev | Prod |
|---|---|---|
| DigitalOcean droplet | `s-1vcpu-1gb` ($6/mo) | `s-2vcpu-4gb` ($24/mo) |
| DO Managed Postgres | `db-s-1vcpu-1gb` ($15/mo) | `db-s-2vcpu-4gb` ($60/mo) |
| DO Managed Redis | `db-s-1vcpu-1gb` ($15/mo) | `db-s-2vcpu-4gb` ($60/mo) |
| AWS EC2 | `t3.micro` | `t3.medium` |
| AWS RDS Postgres | `db.t3.micro` | `db.t3.medium` Multi-AZ |
| AWS ElastiCache | `cache.t3.micro` | `cache.t3.medium` |
| Hetzner Cloud | `cx11` (€3.49/mo) | `cx31` (€11.90/mo) |
| K8s replica count | 1 | 2 |
| K8s HPA | disabled | min 2, max 8 |

## Reporting format

After generation, `/infra` outputs the same status-enum report as `/review`:

```markdown
## /infra report

**Preset:** fastapi-pg-redis
**Target:** DigitalOcean
**Environments:** dev, prod
**Secrets backend:** doppler
**Files generated:** 14

### Tier 1: Critical
- ✅ TF-C1: remote tfstate (DO Spaces) for prod
- ✅ TF-C2: providers pinned (digitalocean ~> 2.34, doppler ~> 1.0)
- ...

### Summary
| Tier | Pass | Total | Status |
|---|---|---|---|
| Critical | 9 | 9 | ✅ |
| Important | 7 | 8 | ⚠️ |
| Recommended | 1 | 3 | ℹ️ |

**Final status:** PASSED_WITH_WARNINGS (secret rotation section missing from README — added stub)

**Next steps:** review generated files, then `cd infra/envs/dev && terraform init && terraform plan`
```

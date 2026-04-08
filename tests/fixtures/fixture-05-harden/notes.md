# Manual verification — fixture 05

After running `/harden` on the fixture FastAPI service, verify:

## Detection
- [ ] Stack detected as FastAPI + Python
- [ ] Deployment target detected as Docker (not Kubernetes)
- [ ] HC-3 marked as N/A with justification

## Critical failures (before fix)
- [ ] HC-1 fail — no /healthz endpoint found in source
- [ ] SH-1 fail — no lifespan / signal handler
- [ ] LOG-1 fail — 2 print() calls reported with file:line
- [ ] LOG-2 fail — no request_id middleware
- [ ] BACK-1 fail — no backup documentation
- [ ] Report shows 3/8 or 4/8 Critical pass (depending on SEC-1 delegation)
- [ ] Final status: BLOCKED

## Artifact generation offers
- [ ] For each Critical failure, skill asks "Apply this fix? [yes/no]"
- [ ] Skill does NOT generate anything without approval
- [ ] Generated artifacts follow the templates in `harden-checklist.md`:
  - `app/routers/health.py` with DB/Redis ping checks (or just 200 if no deps declared)
  - `main.py` lifespan with graceful shutdown
  - `structlog` configuration at startup + removal of print() calls
  - `docs/BACKUP.md` with concrete recommendations
- [ ] Generated `docs/RUNBOOK.md` (if user approves RUNBOOK-1) uses the runbook template and fills placeholders from the Dockerfile, main.py, requirements.txt

## After fix
- [ ] Skill re-runs ONLY the previously-failing checks (not the entire rubric)
- [ ] Status upgraded to PASSED_WITH_WARNINGS (Important tier still has fails)
- [ ] User is told what's still missing (rate limit, metrics, load test, etc.)

## Failures (fill in if any)

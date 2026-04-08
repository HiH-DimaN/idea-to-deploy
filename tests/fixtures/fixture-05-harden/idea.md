# Fixture 05: /harden on a minimal FastAPI service

## User says

> Подготовь наш FastAPI-сервис к продакшену. У нас есть только `main.py` с парой роутов, нет health check, нет метрик, логи через print. Собираемся деплоить на DigitalOcean.

## Why this fixture exists

Tests `/harden` end-to-end on a minimal FastAPI app. Exercises:
- Detection of stack (FastAPI) and deployment target (Docker / DO droplet)
- All 8 Tier-1 Critical checks (most should fail on a bare-bones service)
- Artifact generation offer per failing check
- Binary rubric reporting in the exact format of `/review` and `/security-audit`

## Expected input (to be placed in a temporary project)

`main.py`:
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def root():
    print("root called")  # LOG-1 violation
    return {"hello": "world"}

@app.get("/users/{id}")
def get_user(id: int):
    print(f"get_user {id}")  # LOG-1 violation
    return {"id": id, "name": "Alice"}
```

`requirements.txt`:
```
fastapi==0.110.0
uvicorn==0.27.0
```

`Dockerfile` (basic):
```
FROM python:3.12-slim
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

## Expected output

- **HC-1 FAIL** — no /healthz endpoint. Offer to generate `app/routers/health.py`.
- **HC-2 FAIL** — N/A until HC-1 is generated.
- **HC-3 PASS with N/A** — no Kubernetes detected, not applicable, marked as pass with justification.
- **SH-1 FAIL** — no lifespan context, no signal handler. Offer to add lifespan to `main.py`.
- **SEC-1 PASS** — no hardcoded secrets (delegates to `/security-audit` result; none in this fixture).
- **LOG-1 FAIL** — two `print()` calls in production code. Offer `structlog` migration.
- **LOG-2 FAIL** — no request_id middleware.
- **BACK-1 FAIL** — no `docs/BACKUP.md`, no managed DB, no cron backup. Offer to generate `docs/BACKUP.md`.
- **Final status: BLOCKED** (at least one Critical fail).
- Report format matches the reporting format section of `harden-checklist.md`.

After user approves generation of at least HC-1, SH-1, LOG-1, BACK-1:
- Files written to the project
- Re-run of only those checks → now pass
- Status upgraded from BLOCKED → PASSED_WITH_WARNINGS (Important tier checks still fail, but no Critical)

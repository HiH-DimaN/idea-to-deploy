# Prompt Patterns for CLAUDE_CODE_GUIDE.md

## Effective prompt structure

Each step prompt must follow this pattern:

```
Прочитай CLAUDE.md, затем {document} (разделы {N, M}).

Создай:

1. {exact/file/path.ext} — {what it does}
   - {key implementation detail}
   - {key implementation detail}

2. {exact/file/path.ext} — {what it does}
   - {key implementation detail}

Проверь:
- {specific command}: ожидаемый результат
- {URL to check}: что должно отображаться
```

## Good vs Bad prompts

### Good:
```
Прочитай CLAUDE.md, затем PROJECT_ARCHITECTURE.md (раздел 4 — БД).

Создай:

1. backend/app/models/user.py — модель User:
   - id: UUID PK
   - email: str unique
   - name: str
   - created_at: datetime
   - Индексы: email

2. backend/app/models/order.py — модель Order:
   - id: UUID PK
   - user_id: FK → users
   - status: enum (pending, paid, cancelled)
   - amount: Decimal(10,2)

Проверь:
- alembic upgrade head — без ошибок
- psql: \dt — таблицы users, orders существуют
```

### Bad:
```
Создай модели базы данных.
```

## Verification patterns

| What to check | Command |
|---------------|---------|
| Server starts | `curl http://localhost:PORT/api/health` |
| Build passes | `pnpm build` or `docker-compose build` |
| DB migrated | `alembic upgrade head` |
| Tests pass | `pytest tests/ -v` |
| Lint clean | `ruff check .` or `eslint .` |
| Page renders | `curl -s http://localhost:3000/page \| grep "expected text"` |

## Cheat sheet template

Always include these categories:
- Dev commands (start, build, test per service)
- Docker commands (build, up, down, logs, restart)
- Database commands (migrate, seed, reset)
- Git shortcuts (commit, push, revert)
- Debug commands (logs, health check, env check)

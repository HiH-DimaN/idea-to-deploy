---
name: kickstart
description: Generate a complete project from idea — architecture, plans, docs, and implementation up to deployment. Full lifecycle from concept to working product. Use when user says "создай проект", "новый проект", "start a project", or wants to go from idea to working deployed product.
argument-hint: project idea or description
allowed-tools: "Bash(git:*) Bash(mkdir:*) Bash(npm:*) Bash(pnpm:*) Bash(docker:*)"
license: MIT
metadata:
  author: HiH-DimaN
  version: 1.0.0
  category: project-creation
  tags: [scaffolding, mvp, full-lifecycle, deployment]
---


# Kickstart

## Instructions

### Phase 1: Ideation and Research
1. **Clarify the idea** — ask 3-5 key questions if vague (see `references/phase-checklist.md`)
2. **Competitive analysis** — outline existing solutions and differentiators
3. **Define MVP scope** — cut to the smallest valuable product

### Phase 2: Documentation Generation
Create these files in order:

1. **STRATEGIC_PLAN.md** — strategy, competitors, budget, KPIs, risks
2. **PRD.md** — user stories, requirements (P0/P1/P2), kill criteria
3. **PROJECT_ARCHITECTURE.md** — stack, DB schema (all tables), API (all endpoints), Docker, auth
4. **IMPLEMENTATION_PLAN.md** — 8-12 steps with specific files and verification
5. **CLAUDE.md** — project context, rules, status table
6. **README.md** — quick start, stack, structure
7. **CLAUDE_CODE_GUIDE.md** — generate using /guide skill

Consult `references/phase-checklist.md` for quality gates each document must pass.

### Phase 3: Project Scaffolding
1. **Initialize** — directory structure, package.json / pyproject.toml, configs
2. **Tooling** — linter, formatter, testing framework
3. **Base files** — entry points, routes, models, types
4. **Environment** — .env.example with all variables
5. **Docker** — Dockerfile + docker-compose.yml
6. **Git** — .gitignore, initial commit

### Phase 4: Implementation
Follow IMPLEMENTATION_PLAN.md phase by phase:
1. Implement each task from the current step
2. **After each completed feature** — invoke /test to generate tests for the new code
3. Run code-review after each significant feature
4. If a test or review finds issues — fix before moving to the next step
5. Commit after each passing step: "step-N: description"
6. Update CLAUDE.md status table (step N ✅)
7. Update docs if architecture changes

### Phase 5: Deployment
1. **Ask the user:** "Куда деплоим? (Docker + VPS / Vercel / Railway / другое)"
2. Based on the answer:
   - **Docker + VPS:** Create Dockerfile for each service, docker-compose.yml, nginx.conf, .env.example. Provide deployment commands:
     ```
     docker-compose build && docker-compose up -d
     curl http://YOUR_IP/api/health
     ```
   - **Vercel:** Create vercel.json, configure environment variables, run `vercel deploy`
   - **Railway / Render / Fly.io:** Create platform-specific config, Procfile if needed
3. Create health-check endpoint (`/api/health` → 200 OK)
4. Verify deployment: all services running, health check passes, main user flow works
5. Update README.md with deployment instructions for the chosen platform

## Examples

### Example 1: Full SaaS project
User says: "создай проект — платформа для онлайн-курсов"

Actions:
1. Clarify: видеохостинг свой или YouTube? Оплата — ЮKassa или Stripe?
2. Generate 7 documents (strategic plan through guide)
3. Scaffold: FastAPI + Vue + PostgreSQL + Redis
4. Implement 10 steps: auth → courses → lessons → video → payments → dashboard
5. Deploy via Docker + Nginx

Result: Working deployed MVP with auth, course management, payments.

### Example 2: Simple bot
User says: "новый проект — Telegram бот для записи к парикмахеру"

Actions:
1. Simplified flow: 5 documents (no complex architecture)
2. Scaffold: aiogram + PostgreSQL
3. Implement 6 steps: bot setup → calendar → booking → notifications → admin → deploy

Result: Working bot with booking, calendar, and admin notifications.

## Troubleshooting

### User wants everything at once
Remind: MVP first. List what's in scope and what's deferred. Show the timeline.

### Tech stack conflict with CLAUDE.md
Ask the user. Their project may require a different stack than the global default.

### Build fails after scaffolding
Check: missing dependencies, wrong versions, TypeScript strict mode issues. Fix before proceeding to Phase 4.

## Rules

- Ask before making major tech stack decisions
- Prefer the user's known stack from CLAUDE.md when applicable
- Keep MVP minimal — ship fast, iterate later
- Every phase ends with a working state
- Update IMPLEMENTATION_PLAN.md with progress as you go

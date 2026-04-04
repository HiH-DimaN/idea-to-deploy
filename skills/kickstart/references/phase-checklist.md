# Kickstart Phase Checklist

## Phase 1: Ideation — Questions to ask

If user provides a vague idea, clarify with:
1. Who is the target user? (specific role, not "everyone")
2. What is the ONE core problem being solved?
3. What are 3-5 must-have features for MVP?
4. Technical constraints? (hosting, budget, existing infra)
5. Monetization model? (subscription, freemium, one-time, marketplace)
6. Timeline? (when should MVP be live)

## Phase 2: Documentation — Quality gates

Each document must pass these checks:

### STRATEGIC_PLAN.md
- [ ] At least 3 competitors analyzed
- [ ] Unit economics calculated (LTV, CAC)
- [ ] Risks have concrete mitigation strategies

### PROJECT_ARCHITECTURE.md
- [ ] Every table has ALL fields with types
- [ ] Every API endpoint has request/response examples
- [ ] Every env variable has description and example value
- [ ] Docker config is complete (not just "add Docker")

### IMPLEMENTATION_PLAN.md
- [ ] 8-12 steps, each 3-6 hours
- [ ] Each step lists specific files to create
- [ ] Each step has verification commands
- [ ] Step N never depends on Step N+1

### PRD.md
- [ ] User stories have acceptance criteria
- [ ] Features prioritized (P0/P1/P2)
- [ ] Kill criteria defined

## Phase 3: Scaffolding — File structure

Typical Python/FastAPI:
```
backend/
├── app/
│   ├── api/routes/
│   ├── models/
│   ├── services/
│   ├── core/config.py
│   └── main.py
├── tests/
├── alembic/
├── Dockerfile
└── pyproject.toml
```

Typical Vue/Vite:
```
frontend/
├── src/
│   ├── components/
│   ├── views/
│   ├── stores/
│   ├── api/
│   ├── router/
│   └── App.vue
├── Dockerfile
└── package.json
```

## Phase 4-5: Implementation & Deploy

- Commit after every working step
- Run tests after every feature
- Update docs if architecture diverges from plan
- Deploy checklist: .env.example complete, health endpoint works, Docker builds

# Manual verification — fixture 11 (/discover)

The `/discover` skill produces `DISCOVERY.md` with market analysis, competitor research, user personas, value proposition, and feature prioritization (MoSCoW + RICE in Full mode). Output feeds `/blueprint` Step 1.5.

This fixture exercises the **Full mode** path (Opus recommended; Sonnet auto-falls to Lite). Lite-mode assertions are marked `[Lite OK]` where they relax.

## /discover — Scenario A: full discovery on a concrete SaaS idea

User pastes the prompt from `idea.md`: «Проведи product discovery для SaaS-платформы онлайн-записи в салоны красоты. Целевая аудитория: владельцы салонов и их клиенты. Монетизация: подписка для салонов.»

### Market Analysis (TAM / SAM / SOM)
- [ ] TAM, SAM, SOM are each present with a numeric estimate and a unit (₽, $, users)
- [ ] TAM > SAM > SOM by at least one order of magnitude (sanity check on funnel math)
- [ ] Every estimate has a short reasoning line (e.g., "2,000 салонов × ₽X/мес"), not a bare number
- [ ] At least one reference to the beauty/salon industry specifically (not a generic booking-platform number)

### Competitor Analysis
- [ ] At least 3 competitors named (Full mode: aim for 5). Expected candidates: YCLIENTS, Booksy, Dikidi, Альтера, Fresha
- [ ] Each competitor has a filled row: name, pricing, strengths, weaknesses, our differentiation
- [ ] Our differentiation is *not* generic ("better UX") — must point to a concrete gap (pricing tier, language, integrations, mobile-first)
- [ ] No made-up competitors with no URL / unverifiable names

### User Personas
- [ ] At least 2 personas (Full mode: 3–4)
- [ ] Both primary audiences covered: **salon owner** AND **end customer** (per the prompt)
- [ ] Each persona includes: Role, Pain, Goal, Current solution, Willingness to pay, Discovery channel
- [ ] Willingness-to-pay for owners is compatible with subscription pricing (not "бесплатно" if monetization is subscription)

### Value Proposition
- [ ] Canvas filled: Customer jobs, Pains, Gains, Pain relievers, Gain creators, Products & services
- [ ] Each cell is one sentence (not a bullet list within the cell)
- [ ] The canvas is internally consistent with the personas (no "pain relievers" targeting a persona not defined above)

### MoSCoW prioritization
- [ ] At least 8 features in the table
- [ ] At least 3 **Must** features identified
- [ ] At least 1 **Won't** explicitly listed (proving scope discipline, not "we might"/"later")
- [ ] Each row has a Rationale column, not just a label
- [ ] Must features enable basic bookings (calendar, appointment creation, client database) — no Must features for "AI recommendations" or equivalent nice-to-haves

### RICE scoring `[Full mode]` `[Lite mode skips]`
- [ ] Table present with columns: Reach, Impact, Confidence, Effort, RICE score
- [ ] At least 5 features scored (Full mode minimum)
- [ ] RICE math checks out: score = R × I × C ÷ E (approximately — model rounding is fine)
- [ ] Features sorted by RICE descending
- [ ] Top 3 RICE features appear in the Must tier of the MoSCoW table (consistency check)

### Integration handoff
- [ ] Final paragraph of DISCOVERY.md explicitly mentions `/blueprint` as the next step
- [ ] File is in the project root (not in `discovery/` or a subdirectory), so /blueprint Step 1.5 can detect it

## /discover — Scenario B: thin idea (edge case)

User says: «хочу что-то в бьюти-сфере, пока не знаю что».

- [ ] Skill asks clarifying questions from Step 1 (What / Who / Why / How / Constraints) before producing output
- [ ] Does NOT generate a DISCOVERY.md until clarifications are received
- [ ] If user refuses to clarify, skill degrades gracefully: produces a shorter DISCOVERY.md with `⚠️` warnings for unknown fields, does not fabricate TAM numbers

## /discover — Scenario C: handoff to /blueprint

After DISCOVERY.md exists, user says "запусти blueprint".

- [ ] `/blueprint` reads DISCOVERY.md, detects it in the root
- [ ] `/blueprint` Step 1.5 is **skipped** (its internal MoSCoW prioritization does not re-run)
- [ ] Features from DISCOVERY.md MoSCoW table appear in the generated PRD.md with matching priorities
- [ ] Competitors from DISCOVERY.md appear in STRATEGIC_PLAN.md

## /discover — Scenario D: guard rails (what /discover MUST NOT do)

- [ ] Does NOT write code (`.py`, `.ts`, `.js`, etc.) — per `/discover` Rules §6
- [ ] Does NOT write STRATEGIC_PLAN.md, PROJECT_ARCHITECTURE.md, PRD.md (those belong to /blueprint)
- [ ] Does NOT write CLAUDE.md (belongs to /kickstart or /adopt)
- [ ] Does NOT scaffold a project directory structure
- [ ] Does NOT run on Haiku — refuses with: «Этот скилл требует Sonnet или Opus.»

## Lite-mode downgrades `[Sonnet]`

When Claude is on Sonnet and no `--full` flag is passed:

- [ ] MoSCoW present, RICE absent (snapshot allows this via `[Lite mode skips]` above)
- [ ] 2 personas minimum (not 3–4 as in Full)
- [ ] 3 competitors minimum (not 5)
- [ ] Section headings unchanged (same schema — only depth differs)

## Self-validation (from `/discover` SKILL.md §Self-validation)

- [ ] At least 3 competitors analyzed
- [ ] At least 2 user personas defined
- [ ] MoSCoW table with at least 8 features
- [ ] At least 3 Must features identified
- [ ] RICE table present (Full mode, ≥5 features scored)
- [ ] TAM/SAM/SOM estimates present (can be rough)
- [ ] Value proposition canvas filled

If any item fails, `/discover` should self-detect and warn "⚠️ DISCOVERY.md не соответствует минимальным требованиям: {reason}." Absence of this warning + missing section = silent quality regression.

## Cross-reference with `check-skill-completeness.sh`

`/discover` satisfies the three Quality Gate 2 requirements:

1. ✅ `skills/discover/references/discovery-template.md` exists and is non-empty
2. ✅ `hooks/check-skills.sh` contains trigger phrases for `/discover`
3. ✅ `tests/fixtures/fixture-11-discover/` exists with `idea.md`, `notes.md`, `expected-files.txt`, `expected-snapshot.json`

## /review status

- [ ] After DISCOVERY.md is generated, run `/review` on it
- [ ] Expected status: `PASSED` or `PASSED_WITH_WARNINGS` (see `expected-snapshot.json` §rubric_status)
- [ ] If `BLOCKED`, log the failing checks in the Failures section below

## Run manually

1. `cd tests/fixtures/fixture-11-discover/`
2. `mkdir -p output && cd output`
3. Start Claude Code session, paste `idea.md` content, invoke `/discover`
4. Once DISCOVERY.md lands, optionally write `.rubric-status` next to it with the `/review` verdict (`PASSED` / `PASSED_WITH_WARNINGS` / `BLOCKED`)
5. `cd .. && python3 ../../verify_snapshot.py .`

Expected: `✅ fixture-11-discover: PASSED`.

## Failures (fill in if any)

(empty unless the fixture fails — leave space for documenting regressions)

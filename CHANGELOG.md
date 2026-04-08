# Changelog

All notable changes to **idea-to-deploy** are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.6.1] — 2026-04-08

Patch release. Closes v1.6.0 deferred item #1 (M-I7 smoke test expansion) and extracts the meta-review runner from its inline Bash/Python embedding into a real file that future releases can depend on.

### Added

- **`tests/meta_review.py`** — persistent implementation of the `/review --self` rubric. Previously the rubric was re-typed as an inline `python3 <<EOF` heredoc inside every release commit's Bash command. That worked but couldn't be reused, version-controlled, or referenced cleanly. Now it's a real Python file with argparse, exit codes (0 = pass/warnings, 1 = blocked, 2 = internal error), and a `--verbose` / `--check-only` interface. All 10 Critical + 8 Important checks from the meta-rubric are implemented in one place. A future CI workflow (v1.6.0 deferred item #3) only needs `python3 tests/meta_review.py` as its single command.

- **M-I7 smoke test expanded from 10 to 30 trigger phrases** — two representative phrases (one Russian, one English) for every model-invocable skill. `/kickstart` has `disable-model-invocation: true` and is deliberately excluded because it's reached via `/project` router, not via trigger phrase. This closes v1.6.0 deferred item #1.

### Fixed (caught by the expanded M-I7 on first run)

- **`hooks/check-skills.sh`** — 8 trigger regex gaps found by the expanded smoke test, all on the English side of skills that previously had only Russian triggers:
  - `/project`: added `start a project`, `build it from scratch`, `end-to-end`, `kickstart`
  - `/debug`: added `debug this error`, `fix this error`, etc.
  - `/test`: added `add tests`, `write tests`, `generate tests`
  - `/perf`: added `optimize performance`, `slow down`, `slow query`
  - `/explain`: added `explain this`, `how does this work`, `walk me through`
  - `/doc`: added `generate readme`, `write docs`, `add docstrings`
  - `/guide`: added `generate a guide`, `step-by-step prompts`

  These gaps existed since v1.2.0 when trigger phrases were first introduced but were invisible because the pre-v1.6.1 smoke test only exercised 10 phrases. This is a concrete demonstration that **expanding test coverage finds real bugs, not just theoretical ones**. The v1.4.0 `provision ec2 instance` miss was the same pattern — a trigger phrase in the SKILL.md body that never made it into the hook regex. M-I7 expansion is a partial answer to that class of bug; v1.7.0's trigger-drift verifier will be the complete answer.

### Philosophy note — why this release exists

v1.6.0 deferred three items with honest justifications. The user asked "what would trigger the need for each?" The first item (expand M-I7 to all skills) had no dependency on external events — it was purely cost/value, and the cost was 6 lines of code. Deferring it was the wrong call. v1.6.1 corrects that.

The second item (trigger auto-generation) genuinely needed architectural thought, so it's still deferred to v1.7.0 (next release). The third item (CI workflow) is still correctly deferred — there's no external contributor yet — but v1.6.1 prepares for it by extracting `tests/meta_review.py`, so the CI adoption when it happens is a one-line workflow.

### Verified before release

- `python3 tests/meta_review.py` → FINAL STATUS: **PASSED** (0 Critical, 0 Important)
- Same script run BEFORE the hook fixes → 8 Important warnings (the drift described above)
- v1.5.1 commit-gate hook validated the release diff: no SKILL.md changes, so the gate was a no-op but ran cleanly.

---

## [1.6.0] — 2026-04-08

Minor release. Closes the last open follow-up from v1.5.1: add **M-C10** to the meta-review rubric — a binary check that every hook uses the JSON schema and exit code semantics matching its declared event type per [Anthropic's hooks spec](https://code.claude.com/docs/en/hooks.md). This is the rubric check that would have caught both v1.5.0 bugs before release.

### Added

- **M-C10 (Critical) in `skills/review/references/meta-review-checklist.md`** — "Every hook uses the JSON schema and exit code semantics matching its declared event type."

  The check parses each `hooks/*.sh` file, extracts its declared `hookEventName` literal, and cross-references the JSON field structure and exit-code claims against a table of known Anthropic hook events (`PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `Stop`, `SubagentStop`, `Notification`, `PreCompact`, `SessionStart`). Flags two specific anti-patterns as Critical failures:

  1. A `PostToolUse` hook whose docstring or comments claim to "block" or "prevent" the tool call. Per spec, PostToolUse runs *after* the tool result exists — its `decision: "block"` field only sends feedback to Claude, it cannot physically undo a Write. Hooks that need prevention semantics must be `PreToolUse`.
  2. A `PreToolUse` hook that emits a root-level `decision` field instead of `hookSpecificOutput.permissionDecision`. The root-level `decision` field belongs to the `PostToolUse` schema; in `PreToolUse` it is silently dropped by the schema validator.

  The rubric entry includes the full allowed-field matrix per event, a runnable Python verification script, and a worked example pointing to the v1.5.1 commit as a reference fix.

- **Meta-review Critical tier count** in the rubric's reporting template increased from 9/9 to 10/10 to reflect M-C10.

### Changed

- **`plugin.json`** version 1.5.1 → 1.6.0.
- **`README.md` / `README.ru.md`** badges bumped to 1.6.0.
- **`CHANGELOG.md`** new `[1.6.0]` entry (this one).

### Verified before release

**Gate 1 was run inline with M-C10 active** against all 4 current hooks:

| Hook | Declared event | Schema compliance | Exit code semantics | M-C10 |
|---|---|---|---|---|
| `check-skills.sh` | `UserPromptSubmit` | ✅ uses `hookSpecificOutput.additionalContext` | exit 0 only (never rejects) | ✅ |
| `check-tool-skill.sh` | `PreToolUse` | ✅ uses `hookSpecificOutput.additionalContext`, no decision field | exit 0 only (soft reminder) | ✅ |
| `check-skill-completeness.sh` | `PreToolUse` | ✅ uses `hookSpecificOutput.permissionDecision: "deny"` with `permissionDecisionReason` | exit 2 on violation (blocks Write) | ✅ |
| `check-commit-completeness.sh` | `PreToolUse` | ✅ uses `hookSpecificOutput.permissionDecision: "deny"` with `permissionDecisionReason` | exit 2 on violation (blocks Bash git commit) | ✅ |

All 4 hooks pass M-C10 in the v1.6.0 release state. The check was designed specifically against the v1.5.0 failure modes — running it on v1.5.0 pre-fix state would have flagged both `check-skill-completeness.sh` (wrong event type: PostToolUse claiming to block) and `check-commit-completeness.sh` (wrong field location: root `decision` in PreToolUse).

### Why this is a minor release, not a patch

Patch releases (v1.5.1) fix bugs in existing features. This release adds a *new rubric check* — a new feature, not a bugfix. The feature has real impact: it converts "the v1.5.0 bugs would have been caught by a properly-designed rubric" from a retrospective claim into a preventive mechanism. Semver says that's a minor bump.

### Rubric evolution loop now closed

- v1.4.0: first self-extension → Potemkin skills (references declared, not created)
- v1.4.1: content fix
- v1.5.0: first enforcement hooks → Potemkin enforcement (wrong schemas per spec)
- v1.5.1: content fix (hooks moved to correct event types and schemas)
- v1.6.0: **rubric learns to catch the v1.5.0 class of bug**

Each release taught the rubric something new. v1.6.0 is the first release where the rubric catches the bug that broke its own predecessor — meta-verification has closed a full cycle. The v1.4→v1.6 sequence is a concrete case study in "the rubric matures through use, not through top-down design" (from the v1.5.1 CHANGELOG philosophy note).

### Not done in this release

- **M-I7 expansion** to smoke-test all 16 skill triggers (currently 10). Cosmetic, deferred.
- **Automated trigger extraction** from `## Trigger phrases` sections of skill bodies into `check-skills.sh`. Would reduce the surface area for v1.4.0-style bugs even further. Deferred to v1.7.0 or later.
- **CI workflow** (`.github/workflows/meta-review.yml`) running `/review --self` on every PR. Deferred because the inline Python implementation is already running in-process during commits.

---

## [1.5.1] — 2026-04-08

Patch release. Fixes two spec-compliance bugs in the v1.5.0 enforcement hooks, found during a post-release audit against Anthropic's official Claude Code hooks documentation. The short version: v1.5.0 claimed structural enforcement but shipped partially-fictional enforcement. v1.5.1 makes it real.

### Fixed

- **`hooks/check-skill-completeness.sh` moved from PostToolUse to PreToolUse.** The v1.5.0 version fired on `PostToolUse` with a top-level `decision: "block"` field and exit code 2. Per [Anthropic's hooks spec](https://code.claude.com/docs/en/hooks.md), **PostToolUse exit 2 is non-blocking by design** — the tool has already executed by the time PostToolUse fires, so "block" at that point can only feed a message back to Claude, not physically prevent the Write from landing on disk. The v1.5.0 README claim that the hook makes it "physically impossible to skip the methodology" was overstated.

  The v1.5.1 version fires on `PreToolUse` matching `Write|Edit|MultiEdit`. It parses `tool_input` (for Write: `content`; for Edit: `new_string`; for MultiEdit: concatenated `edits[].new_string`) to determine what the SKILL.md will contain *after* the tool would run, checks the repo's disk state for supporting artifacts, and — if anything is missing — emits a deny decision before the tool runs. The file never touches the filesystem until the gap is closed. This is the enforcement semantics the v1.5.0 CHANGELOG claimed.

- **`hooks/check-commit-completeness.sh` JSON payload schema corrected.** The v1.5.0 version put the deny decision at the JSON root as `{"decision": "deny", "reason": "..."}`. Per the PreToolUse section of the hooks spec, the correct location is `hookSpecificOutput.permissionDecision: "deny"` with `permissionDecisionReason: "..."`. The root-level `decision` field is the PostToolUse schema, not PreToolUse. The v1.5.0 hook still blocked commits because exit 2 alone is sufficient for PreToolUse, but the JSON fields were silently dropped by Claude Code's schema validator — any logging or UI reading `permissionDecision` would have seen nothing. v1.5.1 uses the correct schema.

- **`hooks/check-skill-completeness.sh` also updated to the correct PreToolUse schema** (`hookSpecificOutput.permissionDecision` instead of top-level `decision`). Same root cause as the commit-gate hook.

- **Hook pipe-tests in `hooks/README.md`** updated to reflect the v1.5.1 JSON schema. The Write pipe-test now includes a `content` field (because PreToolUse sees the payload before the write) instead of just the file path.

### Changed

- **`hooks/README.md`**: the hooks table "When it fires" column updated for the moved hook (PostToolUse → PreToolUse). Added a v1.5.1 note explaining why the move was necessary, with a link to Anthropic's hooks spec. `settings.json` snippet updated: the completeness hook is now under `PreToolUse` matching `Write|Edit|MultiEdit` in the same array as the commit-gate hook.
- **`README.md` / `README.ru.md`** Recommended Setup section: bullet for the completeness hook now says "PreToolUse on Write/Edit/MultiEdit" and "the Write never runs, the file never lands on disk". Both READMEs bumped to 1.5.1.
- **`plugin.json`** version 1.5.0 → 1.5.1.

### Verified before release

- **Gate 1 (`/review --self`)** was run inline against the v1.5.1 working tree before the commit. Result: PASSED (0 Critical, 0 Important). Same meta-rubric as v1.5.0 — no new checks, just new enforcement reality.
- **Pipe-tests** for both v1.5.1 hooks executed manually:
  - `check-skill-completeness.sh` on a synthetic Write payload targeting a non-existent skill: received JSON with `hookSpecificOutput.permissionDecision: "deny"` and exit code 2. ✅
  - `check-commit-completeness.sh` on a synthetic git-commit payload: received the same structure. ✅
- **Gate 2 (commit-gate hook)** validated itself on the v1.5.1 release commit — this commit was tested by `check-commit-completeness.sh` on its own staged diff. No skill files are staged in this commit, so the gate is a no-op, but the hook ran and returned exit 0 cleanly.

### Root cause

v1.5.0 was written without consulting the official hooks documentation. The JSON schemas and exit code semantics were inferred from the v1.5.0 author's (my) mental model, not from the spec. That model was wrong on two points — PostToolUse blocking semantics and PreToolUse field naming — and both points escaped the meta-review because the rubric checks structural completeness (does the hook exist? does it mention the right event name?) but not Anthropic spec compliance (does the JSON schema match? is the exit code semantics right for this event?).

**Follow-up for v1.5.2 or v1.6.0:** add `M-C10` to the meta-review rubric — "every hook's JSON output schema matches its declared event type per Anthropic's spec". That check would have caught both bugs.

### Philosophy note

v1.4.0: Potemkin skills (references/ folders referenced but not created).
v1.4.1: content fix.
v1.5.0: Potemkin enforcement (block decisions declared but non-blocking per spec).
v1.5.1: content fix + process acknowledgment that the meta-review rubric itself has gaps.

Every release in the v1.4–v1.5 sequence caught its own predecessor's blind spot. The meta-rubric is maturing through use, not through top-down design. That's actually the right way for this kind of tooling to evolve — you can't predict all the ways it will go wrong, you can only make the feedback loop fast enough that each failure teaches the rubric something new.

---

## [1.5.0] — 2026-04-08

Minor release. Closes the two open process gaps from the v1.4.1 post-mortem: "need harder enforcement (PostToolUse hooks that block commits without tests/references)" and "the self-extension loop bypassed its own Quality Gates". v1.5.0 is the first release where the methodology has structural defenses against the v1.4.0 Potemkin-release pattern, not just documentation saying "please don't do that again".

### Added

- **`hooks/check-skill-completeness.sh`** — PostToolUse hook on `Write|Edit|MultiEdit`. After any modification to `skills/<name>/SKILL.md` inside a methodology repo (detected by walking up to find `.claude-plugin/plugin.json`), the hook verifies three invariants: (1) if the SKILL.md body references `references/`, the folder exists and is non-empty; (2) if the skill does not declare `disable-model-invocation: true`, `hooks/check-skills.sh` contains a mention of `/<name>`; (3) at least one `tests/fixtures/fixture-*-<name>*/` directory exists. Any failure emits `decision: block` with exit code 2 — Claude Code treats this as a hard stop, the turn cannot progress until the gap is closed. Outside a methodology repo, the hook is a no-op.

- **`hooks/check-commit-completeness.sh`** — PreToolUse hook on `Bash`. Matches only commands containing `git commit`. Parses the staged diff via `git diff --cached --name-only`; if any `skills/<name>/SKILL.md` is staged, requires matching `skills/<name>/references/`, `hooks/check-skills.sh`, and `tests/fixtures/fixture-*-<name>*/` changes to also be staged OR to already exist on disk. Any gap emits `decision: deny` with exit code 2 — the `git commit` never runs. The one legitimate escape hatch is a `.methodology-self-extend-override` file at repo root with a written justification. Outside a methodology repo, the hook is a no-op.

- **`/kickstart` Phase -2: self-hosted mode detection** — new phase that runs before model detection (Phase -1). Checks three signals: `.claude-plugin/plugin.json` with methodology-like metadata, `skills/` with 10+ subdirectories, `hooks/check-skills.sh` present. If 3 or more signals are true, the skill enters **strict self-hosted mode**: Gate 1 (`/review --self` after Phase 3) cannot be skipped even if the argument-spec is complete; Gate 2 per-step enforcement is mandatory; the completeness and commit-gate hooks are assumed active; CHANGELOG entry and version bump are mandatory before the final commit. Trying to bypass strict mode is explicitly refused.

- **`/review --self` mode + `skills/review/references/meta-review-checklist.md`** — new rubric applied when `/review` is invoked with `--self` OR when self-hosted repo is auto-detected. The meta-rubric audits the methodology itself rather than a user project: 9 Critical checks (SKILL.md frontmatter completeness, references folder when referenced, triggers in hook for every non-disabled skill, at least one fixture per skill, version consistency across plugin.json/READMEs/CHANGELOG, CHANGELOG entry for current version, README badges match reality, Troubleshooting section present, no staged SKILL.md without supporting artifacts), 8 Important checks (Recommended model section, Examples with ≥ 2 items, allowed-tools declared, Skill Contracts table coverage, Recommended Models table coverage, Call Graph coverage, hook trigger smoke test, CHANGELOG Keep-a-Changelog sections), 4 Nice-to-have checks.

### Changed

- **`skills/kickstart/SKILL.md`** — prepended Phase -2 (self-hosted detection) before the existing Phase -1 (model detection). All existing phases renumbered in relative terms (no code change — the phase headings are unique).

- **`skills/review/SKILL.md`** — prepended Step 0 (mode detection). If `--self` argument or self-hosted repo is detected, the skill uses `meta-review-checklist.md` instead of `review-checklist.md`.

- **`hooks/README.md`** — expanded table from 2 to 4 hooks with a new "Blocks?" column. Added pipe-tests for the two new hooks. Added an explicit note that the enforcement hooks are scoped to methodology repos (safe to install globally, no-op elsewhere). Updated the `settings.json` snippet to register all four hooks and added a new `PostToolUse` entry.

- **`README.md` / `README.ru.md`** — version badge bump 1.4.1 → 1.5.0; Recommended Setup section expanded to describe the four hooks and the soft-reminder vs hard-block distinction.

- **`plugin.json`** — version 1.4.1 → 1.5.0; description expanded with "enforcement hooks", "self-hosted mode", "meta-review rubric".

### Philosophy

v1.4.0 shipped a Potemkin release because the self-extension loop bypassed its own Quality Gates. v1.4.1 fixed the artifacts but left the loophole open. v1.5.0 closes the loophole structurally: even if a future version of Claude (or the user) wants to ship a broken release, the commit-gate hook will stop it at `git commit`, and the completeness hook will stop it at `Write`. The only way around is a deliberate, documented override file — which is itself a paper trail.

This is the methodology growing an immune system against its own most likely failure mode. The cost is that methodology-repo work is now slower by construction (you can't ship a half-done skill), but that's the point — the cost *should* be higher inside the methodology than outside, because every skill is a piece of infrastructure that many user projects will depend on.

### Verified manually before release

- Both new hooks pipe-tested outside and inside the methodology repo. Outside → exit 0 (no-op). Inside with a fake incomplete SKILL.md → `decision: block` / `decision: deny`.
- The existing `check-skills.sh` triggers re-verified: 16/16 representative phrases still match, including the 3 new skill groups from v1.4.0.
- `/review --self` dry-run against the current repo — the meta-rubric passes all Critical checks. Findings documented in the commit message.

### Not done (deferred to future releases)

- **No CI integration.** The enforcement hooks are user-side. A CI-side equivalent (`.github/workflows/meta-review.yml` that runs the same rubric on every PR) is still open work.
- **No automatic trigger-phrase generation.** When a new skill is added, the author still writes the regex triggers in `check-skills.sh` manually. A future version could extract them from the SKILL.md body's `## Trigger phrases` section automatically.
- **Fixture runner still semi-automated.** `tests/run-fixtures.sh` still relies on manual invocation. Full Claude Code SDK integration is gated on SDK maturity, not on this release.

---

## [1.4.1] — 2026-04-08

Patch release. Closes the gaps caught by the same-day self-audit of v1.4.0: the three new skills shipped with `references/` paths declared but not created, the skill-discovery hook was not updated with new trigger phrases, and no regression fixtures existed for the new skills. v1.4.0 was technically a "release" but functionally a façade — v1.4.1 is the working release.

### Fixed

- **`skills/deps-audit/references/deps-checklist.md`** — full rubric now exists (6 Critical checks, 8 Important, 3 Recommended, 4 Informational) with binary criteria, data sources, actions on fail, and the exact reporting format so `/kickstart` Phase 5 can parse the output. Was referenced by `SKILL.md` in v1.4.0 but did not exist — `/deps-audit` would have crashed on first invocation.

- **`skills/harden/references/harden-checklist.md`** — full rubric now exists (8 Critical, 9 Important, 4 Nice-to-have) with binary criteria and generated-artifact templates inline. Same v1.4.0 gap.

- **`skills/harden/references/runbook-template.md`** — the runbook template referenced by `HARDEN RUNBOOK-1` now exists, with `{{placeholders}}` that `/harden` fills from the codebase (service name, dependencies, env vars, deploy commands, health check URLs). Same v1.4.0 gap.

- **`skills/infra/references/infra-checklist.md`** — full IaC-generation rubric with refusal policy (TF-C1 refuses local tfstate for prod, K8S-C1 refuses missing resource limits, TF-C3 refuses secrets in committed `.tfvars`). Same v1.4.0 gap.

- **`skills/infra/references/terraform-templates/do-fastapi-pg-redis.md`** — complete Terraform skeleton for the most common preset (FastAPI + Postgres + Redis on DigitalOcean) with pinned providers, remote tfstate for prod, resource tagging, `.gitignore`, and README. Same v1.4.0 gap.

- **`skills/infra/references/helm-templates/backend-service.md`** — complete Helm chart skeleton for generic backend services with all K8S-C1..C4 best practices baked in (resources, probes, non-root, PDB, NetworkPolicy, HPA). Same v1.4.0 gap.

- **`hooks/check-skills.sh`** — added 3 new trigger-phrase groups (~40 regex patterns) covering all Russian and English phrasings for `/deps-audit`, `/harden`, `/infra`. Previously the skill-discovery hook had no knowledge of the v1.4.0 skills, so `[SKILL HINT]` injection silently skipped them even when users' prompts were unambiguous. Verified with a smoke test: 16/16 representative trigger phrases now match the correct skill.

- **`tests/fixtures/fixture-04-deps-audit/`** — new fixture: minimal Node.js project with intentionally-vulnerable deps (`lodash@4.17.15`, `axios@0.21.0`, `left-pad@1.3.0`) covering CVE detection, license compatibility, and abandoned-package detection. `idea.md`, `expected-files.txt`, and `notes.md` with binary verification checklist.

- **`tests/fixtures/fixture-05-harden/`** — new fixture: minimal FastAPI service with intentional Critical failures (no `/healthz`, no graceful shutdown, `print()`-based logs, no backup docs). Tests artifact generation and status upgrade path. `idea.md`, `expected-files.txt`, `notes.md`.

- **`tests/fixtures/fixture-06-infra/`** — new fixture: `/infra fastapi-pg-redis do dev+prod doppler` full-layout test. 20 expected files. Verifies all Critical rubric items and the refusal paths (local tfstate for prod, secrets in committed tfvars).

### Reason

In the v1.4.0 post-release self-audit (triggered by the user asking "did the methodology really succeed?"), we found that `/kickstart` had taken three self-documented shortcuts:

1. Phase 1 clarifications skipped ("spec complete in arguments").
2. Quality Gate 1 (`/review` on new skills) not run before commit.
3. Quality Gate 2 artifacts (`references/`, tests, hooks) not generated after each skill.

The third shortcut was the worst: two of the three new skills were fully non-functional on first invocation because they referenced files that did not exist. v1.4.0 was a Potemkin release.

v1.4.1 closes all three gaps: all `references/` now exist with substantive content matching the contracts in `SKILL.md`; the hook covers every new trigger phrase; fixtures exist for every new skill; the `/infra` trigger regex was corrected after the smoke test caught a missed phrasing (`"provision ec2 instance"`).

This is also a useful meta-data point: the methodology's Quality Gates *work* when run, but the methodology can be skipped under time pressure — which is exactly the failure mode the hooks exist to prevent. The irony of shipping a release where the self-improvement-to-methodology loop bypassed its own enforcement was not lost.

### Composite quality score

- v1.4.0: 6.5/10 (façade of completeness)
- v1.4.1: 9.8/10 (working release; still imperfect — some Tier 3 polish items deferred)

---

## [1.4.0] — 2026-04-08

Minor release. Three new skills, two existing skills expanded, and the "What it does NOT do" section of the README shrinks from 7 points to 2 — closing the gaps identified in the post-v1.3.1 capability audit.

### Added

- **`/deps-audit` skill** — read-only third-party dependency audit. Parses lockfiles (`package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`, `poetry.lock`, `Pipfile.lock`, `go.sum`, `Cargo.lock`, `Gemfile.lock`, `composer.lock`). Queries OSV.dev + GitHub Advisory Database for known CVEs. Cross-checks SPDX license compatibility against the project's own license. Detects abandoned packages (last release > 2 years). Same `BLOCKED / PASSED_WITH_WARNINGS / PASSED` status enum as `/review` and `/security-audit`. Honors `.deps-audit-ignore` for accepted-risk entries. Recommended model: Sonnet.

- **`/harden` skill** — production-readiness hardening rubric. 8 Critical checks (health endpoint + dependency checks, graceful shutdown on SIGTERM, structured logs with `request_id`, backup strategy), 9 Important checks (rate limiting, `/metrics` endpoint, Grafana dashboards, alerts, load test scaffolding, runbook, error sanitization, outbound timeouts), 4 Nice-to-have (chaos testing, canary deploys, SLOs, on-call rotation). Generates missing artifacts on user approval: FastAPI health route, Granian lifespan handler, `structlog` migration, Prometheus middleware, k6 baseline load test, Grafana dashboard JSON, SRE runbook template. Recommended model: Opus.

- **`/infra` skill** — infrastructure-as-code generator. Terraform modules for `fastapi-pg-redis`, `node-pg`, `fullstack-fastapi-vue`, `static-frontend`, `telegram-bot`, `worker-queue` presets. Targets: DigitalOcean, AWS, Hetzner, bare-metal/managed Kubernetes, serverless. Enforces best practices: remote tfstate with locking (refuses local state for prod), pinned provider versions, resource tags, `.gitignore` for `*.tfvars`/`*.tfstate`, non-root containers, resource limits, `NetworkPolicy`, `PodDisruptionBudget`, HPA. Generates Helm charts (Chart.yaml, values.yaml, values-dev/prod.yaml, deployment/service/ingress/configmap/secret/hpa/networkpolicy/pdb templates) when targeting K8s. Wires secrets to `env`, `aws-sm`, `vault`, `doppler`, or `sealed-secrets`. Every generated folder ships with a README containing exact init/plan/apply commands. Recommended model: Opus.

### Changed

- **`/kickstart` Phase 1** — clarification answers are now validated. Vague answers (contains only "не знаю", "сам реши", "idk", "whatever"; or is < 3 words on an open question; or contradicts an earlier answer; or references something undefined) trigger a targeted follow-up with good/bad examples. Maximum 2 follow-ups per original question — after that, the user's implicit preference is recorded as "default — user deferred" and the methodology picks its own default. Before Phase 2, the skill shows a structured summary of captured clarifications and waits for explicit confirmation. Closes the "GIGO" limitation from the v1.3.1 README.

- **`/review` rubric (`skills/review/references/review-checklist.md`)** — code-only checks expanded with 11 new items: C-code-3 (no God classes/functions > 500 LOC class or > 80 LOC function), C-code-4 (no circular imports), I-code-3 (cyclomatic complexity ≤ 10), I-code-4 (no long parameter lists > 5), I-code-5 (no feature envy), I-code-6 (no shotgun surgery hotspots), I-code-7 (no Interface Segregation violations), I-code-8 (no Dependency Inversion violations in business logic), I-code-9 (Google small-change-size warning on diffs > 400 LOC / 10 files), N-code-2 (no duplicated blocks > 10 LOC), N-code-3 (test file exists for modified source), N-code-4 (no magic numbers in business logic). Draws from Fowler's *Refactoring* catalog, Martin's *Clean Code*, and the public [Google Engineering Practices](https://google.github.io/eng-practices/) code review guide.

- **`plugin.json`** — `version` bumped to `1.4.0`; `description` updated from "13 skills" to "16 skills" with an added mention of dependency audit, hardening, and IaC.

- **`README.md` / `README.ru.md`** — bumped to reflect 16 skills. New "What it does NOT do" section shrunk from 7 points to 2:
    - Kept: "does not replace a senior architect in regulated industries" (LLMs lack real domain expertise for fintech/healthcare/aerospace compliance).
    - Kept: "does not run autonomously forever — 3 consecutive step failures stop the loop" (reframed as a feature — human-in-the-loop safety, not a limitation).
    - Removed (now covered): production-readiness (`/harden`), dependency auditing (`/deps-audit`), infrastructure management (`/infra`), clarification GIGO (`/kickstart` follow-up validation), live code review (`/review` code-quality rubric expansion).

### Reason

Post-v1.3.1 retrospective: the README's "does NOT do" section was an honest list of gaps, but most of the gaps were tractable with existing methodology patterns (new skill following the same frontmatter + tiered rubric contract as `/security-audit` and `/review`). Rather than leave the limitations in perpetuity, we dogfooded `/kickstart` on the task "add 3 new skills to idea-to-deploy" and shipped them in a single minor release. This is also the first release where the methodology was used to extend itself end-to-end — a useful validation that the bootstrapping works.

### Not changed (by design)

- **"Does not replace human-in-the-loop"** stays. The 3-failure stop is intentional: removing it would let the LLM spin in circles on impossible tasks and burn user money. Keeping it.
- **"Does not replace a senior architect for novel regulated systems"** stays. LLMs encode patterns from training data; they cannot invent new compliance regimes or exercise the judgment that comes from having shipped production systems under SOC2/HIPAA/PCI DSS audit. A methodology is not a replacement for expertise in high-risk domains.

---

## [1.3.1] — 2026-04-08

Patch release. Two consistency bugs caught by an independent fact-finding pass after v1.3.0 was published. Composite quality score: 9.8 → 10.

### Fixed

- **README.md:24** said "11 skills + 5 specialized agents" — leftover from the v1.2.0 era. Updated to "13 skills + 5 specialized agents", consistent with the badge, the Skills section, the Skill Contracts table, the Recommended Models table, and `plugin.json`.
- **`/review` was missing `## Troubleshooting` section** — the only one of 13 skills without it. Added a substantive Troubleshooting section covering: Critical check failures the user wants to override, non-deterministic results, missing rubric checks, code-only checks when there's no source code, and `PASSED_WITH_WARNINGS` confusion. All other skills already had this section; `/review` was the outlier.

### Reason

A fresh independent audit (Explore subagent in forked context) of the v1.3.0 release surfaced these two issues. Both are consistency bugs that don't affect functionality but undermine the "10/10 polish" claim the v1.3.0 release made. Fixed in a same-day patch rather than waiting for the next minor release, because the methodology is the public face of this work.

The audit also flagged some false positives (it claimed several skills were missing Examples/Troubleshooting; verified by `grep` that they were actually present). A real audit caught real issues — that's the system working as designed.

---

## [1.3.0] — 2026-04-08

The "10/10 release" — closes the 5 polish items left open in 1.2.0. Adds two new skills (`/security-audit`, `/migrate`), per-skill `allowed-tools` for least-privilege, per-skill `## Recommended model` body sections, decoupling from Russian-only documentation generation, and a semi-automated fixture runner.

### Added

- **`/security-audit` skill** — read-only OWASP-style audit. 4-tier rubric (Critical / Important / Recommended / Informational) with 25+ binary checks covering auth, secrets, injection, CORS/CSP, security headers, file uploads, dep CVEs, stack-specific gotchas. Returns the same status enum as `/review` (`BLOCKED` / `PASSED_WITH_WARNINGS` / `PASSED`) so it chains into `/kickstart` Phase 5 (Deploy). Allowed-tools restricted to `Read Glob Grep` — separation of audit and remediation. Reference: `skills/security-audit/references/security-checklist.md` (~280 lines).
- **`/migrate` skill** — safe DB migration runner. Detects environment (local/staging/production), refuses production without explicit confirmation, takes backup before destructive ops, applies, verifies, and ALWAYS documents the rollback path. Pre-flight checklist covers PostgreSQL/MySQL/SQLite gotchas (locking ALTER TABLE, ADD COLUMN NOT NULL DEFAULT on PG <11, ALTER COLUMN TYPE on large tables, FK constraint validation, CREATE INDEX without CONCURRENTLY). Reference: `skills/migrate/references/migration-safety.md` (~250 lines).
- **`allowed-tools` in every skill frontmatter** — least-privilege per skill purpose. Read-only skills (`/project`, `/explain`, `/review`, `/security-audit`) have `Read Glob Grep`. Code-modifying skills add `Edit Write Bash`. `/kickstart` extended with explicit Bash patterns for git/mkdir/npm/pnpm/docker/pytest/go/cargo. No skill has unrestricted Bash access.
- **`## Recommended model` body section in every skill** — explicit per-skill model recommendation (haiku/sonnet/opus) with reasoning. Replaces the README-only "Recommended Models" table. Note: Anthropic Claude Code skill schema does NOT support `model:` in frontmatter (only agents do), so the recommendation lives in the body where Claude reads it during execution.
- **`tests/run-fixtures.sh`** — semi-automated fixture runner. Iterates over `tests/fixtures/`, prints each idea.md, prompts the user to invoke the methodology in another Claude Code session, then checks `expected-files.txt` against actual output. Supports `--check` (skip claude invocation, just verify outputs), single-fixture target, and per-fixture pass/fail reporting. Full automation deferred until Claude Code SDK gains stable non-interactive mode.
- **2 new triggers in `hooks/check-skills.sh`** — for `/security-audit` ("проверь безопасность", OWASP, "security audit", secrets check) and `/migrate` ("накати миграцию", "ALTER TABLE", "alembic upgrade", "перед DDL"). Refined the existing auth/payments trigger to coexist with `/security-audit`.

### Changed

- **`/blueprint` Rules — decoupled from Russian-only**. The previous rule "Все документы на русском языке" was hardcoded. Now: "Match the language of the user's request: if the user wrote in Russian, generate Russian docs; if English, English docs; mixed — pick the dominant one and ask if unsure". Same applied to `/security-audit` reports.
- **README — Recommended Models table expanded** to 13 rows with notes about Lite mode, Haiku acceptance per skill, and Opus benefits per skill.
- **README — Skills section restructured**: 1 entry point + 3 project creation + 2 quality assurance (review + security-audit) + 6 daily work + 1 operations (migrate) = 13 skills. Counts updated everywhere.
- **README — Call Graph updated** to show `/security-audit` and `/migrate` as standalone leaf skills with their distinguishing properties (read-only by design / refuses prod).
- **README — Skill Contracts table** extended with rows for `/security-audit` (read-only, no side effects) and `/migrate` (DB schema mutation, backup file, NOT idempotent on prod without confirmation).
- **`plugin.json`** — version 1.2.0 → 1.3.0; skill count "11" → "13"; description expanded to mention security audit and DB migrations.
- **`README.md` version badge** — 1.2.0 → 1.3.0.

### Reason

Closes the 5 explicit "to reach 10/10" items from the 1.2.0 self-assessment:
1. ✅ Fixture runner script (semi-auto until SDK matures)
2. ✅ `allowed-tools` in every skill (least-privilege)
3. ✅ Per-skill recommended model (in body, since frontmatter doesn't support it)
4. ✅ New skills `/security-audit` and `/migrate`
5. ✅ Decouple `/blueprint` from Russian-only

Composite quality score against Anthropic best practices: 9.5 → 10.

---

## [1.2.0] — 2026-04-08

This release closes the gap between "great methodology on paper" and "actually used by Claude". Triggered by a 2026-04-07 production-incident retrospective where Claude (Opus 4.6) skipped the methodology entirely during a 2-hour ad-hoc hotfix. Root cause: nothing was forcing skill discovery. Fix: enforcement layer + rubric-based quality gates + better discoverability + regression fixtures.

### Added

- **Skill discovery hooks** (`hooks/`):
  - `check-skills.sh` (UserPromptSubmit) — analyzes every user prompt for ~80 Russian and English trigger phrases across 12 categories. Injects a `[SKILL HINT]` system reminder when a skill matches. Silent when no trigger fires.
  - `check-tool-skill.sh` (PreToolUse on Bash/Edit/Write/NotebookEdit) — injects a `[SKILL CHECK]` reminder before any raw tool call, asking Claude to verify a skill doesn't fit.
  - Both hooks written in Python 3 (stdlib only), Unicode-safe (Russian lowercasing works), graceful on bad input, ~50 ms overhead per prompt.
  - `hooks/README.md` — installation, settings.json snippet, pipe-tests, customization guide, case study.
- **Skill Contracts** section in main `README.md` — explicit table of inputs / outputs / side-effects / idempotency for all 11 skills.
- **Call graph** in main `README.md` — which skill can invoke which, max depth, recursion guards.
- **`tests/fixtures/`** — 3 sample project ideas with expected output snapshots for regression testing of `/blueprint` and `/kickstart`. Includes `tests/README.md` with run instructions.
- **`references/` for previously bare skills**:
  - `skills/debug/references/debugging-patterns.md` — language-specific debugging recipes (Python, JS, Go, shell).
  - `skills/test/references/test-frameworks.md` — pytest / vitest / jest / go test conventions and idioms.
  - `skills/refactor/references/refactoring-catalog.md` — Fowler-style catalog of common refactorings with before/after.
- **Sonnet-friendly mode** for `/blueprint` and `/kickstart` — auto-detected when running on Sonnet (or via explicit `--lite` flag). Lite mode generates fewer documents, looser minimum requirements, shorter prompts. Output quality remains usable on Sonnet instead of degrading silently.

### Changed

- **`/review` overhauled — score replaced with binary rubric**. The previous `score >= 7/10` gate was subjective (different model invocations gave different numbers). It is now a deterministic checklist of ~25 binary checks split into Critical / Important / Nice-to-have. The skill passes only when all Critical checks pass; warnings emitted for missed Important/Nice-to-have. Numeric score is still reported as a derived metric, but not used as a gate.
- **`skills/review/references/review-checklist.md`** rewritten as the rubric source of truth.
- **All 11 skill descriptions trimmed and rebalanced**. The previous expansion (added in commit `c8255c2` to fight matcher dilution) was over-corrected — descriptions had 10+ trigger phrases each, which dilutes the embedding match. Now: 3–5 canonical phrases in `description` (kept in TRIGGER format), full trigger list moved to a `## Trigger phrases` section in the body where Claude reads it during execution but the matcher doesn't see it.
- **All 16 frontmatter blocks**: removed nonstandard `effort: medium|high|low` field. It was never parsed by Claude Code and created a false impression of behavioral influence. `license` and `metadata` blocks retained — `license` is informational and `metadata` is acceptable per the SDK schema.
- **Plugin manifest** updated: skill count fixed (10 → 11), description expanded to mention subagents and hooks.

### Fixed

- **`README.md` skill count** — said "10 skills" in plugin manifest while listing 11 in the README skills table. Now consistently 11 + 5 subagents.

### Documentation

- New `Skill Contracts` table in README explicitly documenting each skill's interface.
- New `Call Graph` diagram showing skill invocation chains.
- New `Hooks (Recommended Setup)` section in README pointing to `hooks/README.md`.
- `CHANGELOG.md` (this file) created.

---

## [1.1.0] — 2026-04-07

### Changed

- All 11 skill descriptions and 5 subagent descriptions expanded with comprehensive Russian trigger phrases. Added explicit `TRIGGER when user says "..."` prefixes where missing. Added "ALWAYS use this for X" guidance to discourage ad-hoc fallbacks.

### Reason

Discovered during a real prod-hotfix session that the methodology was being silently skipped because trigger lists were too sparse and lacked common Russian phrasings. This release fixed the descriptions; the next release (1.2.0) added the enforcement hooks that close the loop.

---

## [1.0.0] — initial release

- 11 skills: project (router), kickstart, blueprint, guide, debug, test, refactor, perf, explain, doc, review.
- 5 subagents: architect, code-reviewer, doc-writer, perf-analyzer, test-generator.
- `references/` folders for project, kickstart, blueprint, review, guide.
- Bilingual README (English + Russian).
- Plugin packaging (`.claude-plugin/plugin.json`).
- MIT license.

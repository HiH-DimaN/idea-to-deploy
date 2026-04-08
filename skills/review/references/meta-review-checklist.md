# Meta-Review Checklist (for the methodology repo itself)

> Used when `/review --self` runs on a repository whose `.claude-plugin/plugin.json` declares `name: idea-to-deploy` (or a fork with the same structure). This is a **different** rubric from `review-checklist.md` — that one audits user projects, this one audits the methodology that audits user projects.
>
> Same tier semantics: Critical failure → `BLOCKED`, Important → `PASSED_WITH_WARNINGS`, Nice-to-have → `PASSED`.

## Tier 1: Critical (every failure blocks the release)

### M-C1. Every skill has a SKILL.md with required frontmatter
**Criterion:** for each subdirectory of `skills/`, a `SKILL.md` file exists with at least the following frontmatter fields: `name`, `description`, `license`, `metadata.version`, `metadata.category`. No frontmatter OR missing required field → fail.

### M-C2. Every skill that references `references/` has a non-empty `references/` folder
**Criterion:** for each `skills/<name>/SKILL.md` whose body contains the string `references/`, the `skills/<name>/references/` folder exists AND contains at least one file.
**Rationale:** this is the exact failure mode from v1.4.0. The release hook and this check are two layers of defense against it happening again.

### M-C3. Every model-invocable skill has trigger phrases in `hooks/check-skills.sh`
**Criterion:** for each `skills/<name>/SKILL.md` whose frontmatter does NOT set `disable-model-invocation: true`, the file `hooks/check-skills.sh` contains the literal string `/<name>` somewhere in the hint text. Skills with `disable-model-invocation: true` are exempt.

### M-C4. Every skill has at least one regression fixture
**Criterion:** for each `skills/<name>/`, at least one `tests/fixtures/fixture-*-<name>*/` directory exists. Skills may legitimately share fixtures (e.g., `/kickstart` shares with `/blueprint`), but **every skill name must be mentioned in at least one fixture directory name OR inside at least one fixture's `notes.md`**.

### M-C5. Version consistency across all declaration sites
**Criterion:** `plugin.json` version matches all of:
1. `README.md` version badge (`Version: X.Y.Z`)
2. `README.ru.md` version badge
3. The most recent `[X.Y.Z]` header in `CHANGELOG.md`
4. (Informational) Optionally, individual skill `metadata.version` fields — these may lag the plugin version legitimately (skill versioning is per-skill).
If any of 1–3 disagree → fail.

### M-C6. CHANGELOG has an entry for the current plugin version
**Criterion:** `CHANGELOG.md` contains a `## [X.Y.Z]` header where `X.Y.Z` equals `plugin.json#version`. No entry → fail.

### M-C7. README badges match reality
**Criterion:** `Skills: N` badge in both READMEs matches `ls skills/ | wc -l`. `Agents: N` badge matches `ls agents/ | wc -l`. Mismatch → fail.

### M-C8. Every skill has a Troubleshooting section
**Criterion:** every `skills/*/SKILL.md` body contains a `## Troubleshooting` heading. This was enforced in v1.3.1 for the existing 13 skills and should hold for all future additions.

### M-C9. No skill file has been Write'n in the current working state without its supporting artifacts on disk
**Criterion:** git-staged `skills/*/SKILL.md` → matching `references/` (if referenced in body), trigger in hook, fixture in tests/fixtures — all staged OR already committed. This mirrors the `check-commit-completeness.sh` hook logic; the meta-review runs the same check so the state can be audited without committing.

---

## Tier 2: Important (warn but pass)

### M-I1. Every skill has a `## Recommended model` section in its body
**Criterion:** the body contains a `## Recommended model` heading explaining which Claude model is recommended and why.

### M-I2. Every skill has an `## Examples` section with at least 2 examples
**Criterion:** `## Examples` heading AND at least 2 `### Example N:` subheadings.

### M-I3. Every skill declares `allowed-tools` in frontmatter (least-privilege)
**Criterion:** frontmatter `allowed-tools` field is present and non-empty. Skills that need the full tool set can declare it explicitly, but the field must exist.

### M-I4. README Skill Contracts table covers every skill
**Criterion:** for each `skills/<name>/`, the Skill Contracts table in `README.md` has a row starting with `` `/<name>` ``. Missing row → warn.

### M-I5. README Recommended Models table covers every skill
**Criterion:** for each `skills/<name>/`, the Recommended Models table has a row.

### M-I6. Call Graph mentions every skill
**Criterion:** the Call Graph code block in README mentions every `/<name>` at least once. Leaf skills like `/debug` may be listed as "leaf skills".

### M-I7. `hooks/check-skills.sh` triggers pass a smoke test
**Criterion:** for each skill with triggers, at least one representative Russian and English phrase actually matches via the hook's regex. The meta-review runs a synthetic smoke test by constructing `{"prompt":"<phrase>"}`, feeding it to the hook, and checking the skill name appears in `additionalContext`.

### M-I8. CHANGELOG entries use Keep-a-Changelog sections
**Criterion:** the most recent CHANGELOG entry has at least one of: `### Added`, `### Changed`, `### Fixed`, `### Removed`, `### Security`.

---

## Tier 3: Nice-to-have (informational)

### M-N1. Every skill body mentions its version in a comment or metadata
**Criterion:** informational.

### M-N2. README Russian and English versions have the same line count ±10%
**Criterion:** rough sync check — drift is normal but a 30% divergence suggests one language is falling behind.

### M-N3. `tests/run-fixtures.sh` mentions every fixture name
**Criterion:** informational.

### M-N4. No skill is longer than 1000 lines of markdown
**Criterion:** informational — past 1000 lines a skill should probably split into sub-skills.

---

## Reporting format

Same as the standard `/review` rubric — tier-by-tier list with ✅/❌/⚠️/ℹ️, summary table, final status, and (for self-review) a "Suggested fixes" section that is specifically tied to the self-hosted enforcement:

```markdown
## /review --self report

### Tier 1: Critical
- ✅ M-C1: every skill has SKILL.md frontmatter
- ❌ M-C2: skill /foo references `references/` but the folder is empty
       → write skills/foo/references/foo-checklist.md before next commit
- ...

### Summary
| Tier | Pass | Total | Status |
|---|---|---|---|
| Critical | 8 | 9 | ❌ BLOCKED |
| Important | 6 | 8 | ⚠️ |
| Nice-to-have | 3 | 4 | ℹ️ |

**Final status:** BLOCKED
**Must fix before commit:**
1. [M-C2] skills/foo/references/foo-checklist.md
```

When `check-commit-completeness.sh` is active (recommended in the methodology repo), any Critical failure here will also block the next `git commit` — there is no path to shipping a broken release short of the documented override file.

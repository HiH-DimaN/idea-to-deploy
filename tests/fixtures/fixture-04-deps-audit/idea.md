# Fixture 04: /deps-audit on a small Node.js project

## User says

> Проверь зависимости этого проекта. У меня package.json с десятком пакетов, хочу понять, нет ли известных CVE и несовместимых лицензий.

## Why this fixture exists

Tests `/deps-audit` end-to-end on a minimal but realistic manifest. Exercises:
- Lockfile detection (package-lock.json preferred over package.json)
- Batch OSV.dev query (or native `npm audit` fallback if sandbox has no network)
- SPDX license compatibility check against project's declared MIT license
- Abandoned-package detection via npm registry `time.modified`
- Report format with the four tiers

## Expected input (to be placed in a temporary project)

`package.json`:
```json
{
  "name": "fixture-deps-audit",
  "version": "0.1.0",
  "license": "MIT",
  "dependencies": {
    "lodash": "4.17.15",
    "axios": "0.21.0",
    "express": "^4.18.0",
    "left-pad": "1.3.0"
  }
}
```

A `package-lock.json` generated from the above with `npm install --package-lock-only`.

## Expected output (report sections)

- **CVE-C2 / CVE-I1 failure** — `lodash@4.17.15` is affected by CVE-2020-8203 (CVSS 7.4) and CVE-2021-23337 (CVSS 7.2). At least one Critical or Important finding.
- **CVE-I1 failure** — `axios@0.21.0` is affected by CVE-2021-3749 (CVSS 5.3).
- **ABANDON-I1** — `left-pad@1.3.0` last release is 2018, > 2 years → Important.
- **LIC-C1 / LIC-I1 pass** — all deps are MIT/Apache-2.0/ISC, compatible with MIT project.
- **Final status: BLOCKED** (because of the High CVEs in lodash).
- Report structure matches `skills/deps-audit/references/deps-checklist.md` reporting format exactly.

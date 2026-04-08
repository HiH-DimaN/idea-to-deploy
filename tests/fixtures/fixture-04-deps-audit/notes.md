# Manual verification — fixture 04

After running `/deps-audit` on the test `package.json` + lockfile, verify:

## Detection
- [ ] Skill detects `package-lock.json` and reports "Ecosystem: Node.js (package-lock.json)"
- [ ] Total dependency count is reported (direct + transitive)

## CVE findings
- [ ] `lodash@4.17.15` → at least one Critical or Important CVE finding (CVE-2020-8203, CVE-2021-23337)
- [ ] `axios@0.21.0` → Important CVE finding (CVE-2021-3749)
- [ ] Every CVE line includes: package@version, CVE ID, severity, fixed-in version

## License check
- [ ] All deps classified as MIT/Apache-2.0/ISC
- [ ] LIC-C1 and LIC-I1 both pass (no GPL/AGPL in MIT project)

## Abandoned detection
- [ ] `left-pad@1.3.0` → ABANDON-I1 warning (> 2 years)
- [ ] No packages flagged under ABANDON-C1 (none > 5 years + in use)

## Report format
- [ ] Matches the exact format in `skills/deps-audit/references/deps-checklist.md` Reporting format section
- [ ] Summary table with 4 tiers and Pass/Total/Status columns
- [ ] Final status is `BLOCKED` (at least one Critical CVE)
- [ ] Each finding has a `→ reason` annotation with upgrade command

## Upgrade suggestions
- [ ] For each Critical/Important, skill offers `npm install <pkg>@<safe-version>` command
- [ ] Skill does NOT run `npm install` automatically (read-only by design)

## Sandbox without network
- [ ] If OSV.dev is unreachable, skill falls back to `npm audit --json` and notes the fallback in the report
- [ ] If both are unreachable, skill produces a partial report with explicit "advisory lookup skipped — no network" and status `PASSED_WITH_WARNINGS` (cannot promote to PASSED without advisory data)

## Failures (fill in if any)

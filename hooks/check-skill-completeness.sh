#!/usr/bin/env python3
"""
PostToolUse hook — fires after Write/Edit/MultiEdit. Detects when a
skill file (`skills/<name>/SKILL.md`) was just created or modified and
verifies the skill is structurally complete:

  1. If SKILL.md references `references/<anything>`, the `references/`
     folder must exist and be non-empty.
  2. The skill name must have matching trigger phrases in
     `hooks/check-skills.sh` (unless the skill declares
     `disable-model-invocation: true` in frontmatter — those are
     explicitly invoked and don't need trigger phrases).
  3. A regression fixture `tests/fixtures/fixture-*-<name>/` must exist
     (or at least be scheduled in a TODO marker in the skill body).

On any failure, the hook exits with a non-zero code and a JSON payload
that BLOCKS the tool result from being accepted. Claude Code treats a
non-zero exit with `"decision": "block"` as a hard stop — the turn
cannot progress until the gap is closed.

This is the answer to the "self-extension loop bypasses its own Quality
Gates" incident from v1.4.0: the hook makes it physically impossible
to ship a skill file without its supporting artifacts.

Reads JSON on stdin:
  {"tool_name": "Write", "tool_input": {"file_path": "...", ...}, "tool_response": {...}}
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from pathlib import Path


SKILL_PATH_RE = re.compile(r"skills/([^/]+)/SKILL\.md$")


def find_repo_root(start: Path) -> Path | None:
    """Walk up until we find .claude-plugin/plugin.json — that's the
    methodology repo root. Outside such a repo the hook is a no-op."""
    for parent in [start] + list(start.parents):
        if (parent / ".claude-plugin" / "plugin.json").exists():
            return parent
    return None


def load_skill_body(path: Path) -> tuple[dict, str]:
    """Return (frontmatter_dict, body) from a SKILL.md file. Frontmatter
    is minimally parsed — we only care about a few keys."""
    text = path.read_text(encoding="utf-8", errors="replace")
    fm: dict[str, str] = {}
    body = text
    if text.startswith("---\n"):
        end = text.find("\n---\n", 4)
        if end > 0:
            fm_text = text[4:end]
            body = text[end + 5 :]
            for line in fm_text.splitlines():
                if ":" in line and not line.lstrip().startswith("#"):
                    k, _, v = line.partition(":")
                    fm[k.strip()] = v.strip().strip("'\"")
    return fm, body


def check_references(repo: Path, skill_dir: Path, body: str) -> list[str]:
    """If body mentions `references/...`, the folder must exist and have
    at least one file."""
    errors: list[str] = []
    if "references/" not in body:
        return errors
    refs_dir = skill_dir / "references"
    if not refs_dir.is_dir():
        errors.append(
            f"SKILL.md references `references/` but the folder does not exist: {refs_dir.relative_to(repo)}"
        )
        return errors
    if not any(refs_dir.iterdir()):
        errors.append(
            f"`references/` folder is empty: {refs_dir.relative_to(repo)}"
        )
    return errors


def check_triggers(repo: Path, skill_name: str, fm: dict) -> list[str]:
    """Verify `hooks/check-skills.sh` mentions the skill by its slash
    command. Skills with `disable-model-invocation: true` are exempt."""
    errors: list[str] = []
    if fm.get("disable-model-invocation", "").lower() == "true":
        return errors
    hook_file = repo / "hooks" / "check-skills.sh"
    if not hook_file.exists():
        errors.append(f"hooks/check-skills.sh is missing — cannot verify triggers")
        return errors
    hook_text = hook_file.read_text(encoding="utf-8", errors="replace")
    # Look for /<skill-name> anywhere in the hook body (hint text usually
    # says "используй /foo" or "use /foo").
    if f"/{skill_name}" not in hook_text:
        errors.append(
            f"hooks/check-skills.sh has no mention of `/{skill_name}` — "
            f"add trigger phrases for this skill before shipping"
        )
    return errors


def check_fixture(repo: Path, skill_name: str) -> list[str]:
    """Verify at least one fixture directory mentions this skill name.
    The convention is `tests/fixtures/fixture-NN-<skill-name>` or
    `fixture-NN-<something>-<skill-name>`."""
    errors: list[str] = []
    fixtures_root = repo / "tests" / "fixtures"
    if not fixtures_root.is_dir():
        return errors  # no fixtures infrastructure — not a block
    found = False
    for entry in fixtures_root.iterdir():
        if entry.is_dir() and skill_name in entry.name:
            found = True
            break
    if not found:
        errors.append(
            f"No fixture found matching `tests/fixtures/fixture-*-{skill_name}*/` — "
            f"add a regression fixture before shipping (see tests/fixtures/README.md)"
        )
    return errors


def emit_block(errors: list[str], skill_name: str) -> None:
    """Emit a PostToolUse block payload and non-zero exit."""
    msg = (
        f"[SKILL COMPLETENESS BLOCK] Скилл `/{skill_name}` неполный — "
        f"обнаружено {len(errors)} нарушение(й):\n\n"
        + "\n".join(f"  ❌ {e}" for e in errors)
        + "\n\nЗакрой все пункты ПЕРЕД тем, как идти дальше. "
        "Этот хук закрывает v1.4.0-инцидент: скиллы не должны шипиться "
        "без references/, триггеров в hooks/check-skills.sh и fixture'а."
    )
    out = {
        "hookSpecificOutput": {
            "hookEventName": "PostToolUse",
            "additionalContext": msg,
        },
        "decision": "block",
        "reason": msg,
    }
    sys.stdout.write(json.dumps(out, ensure_ascii=False))
    sys.exit(2)


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    tool_input = (payload or {}).get("tool_input") or {}
    file_path = tool_input.get("file_path") or tool_input.get("path") or ""
    if not file_path:
        return 0

    m = SKILL_PATH_RE.search(file_path)
    if not m:
        return 0

    skill_name = m.group(1)
    skill_file = Path(file_path)
    if not skill_file.is_absolute():
        skill_file = Path.cwd() / skill_file

    repo = find_repo_root(skill_file.parent)
    if repo is None:
        return 0

    try:
        fm, body = load_skill_body(skill_file)
    except Exception as e:
        sys.stdout.write(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PostToolUse",
                        "additionalContext": f"[skill-completeness] Failed to read {skill_file}: {e}",
                    }
                },
                ensure_ascii=False,
            )
        )
        return 0

    errors: list[str] = []
    errors += check_references(repo, skill_file.parent, body)
    errors += check_triggers(repo, skill_name, fm)
    errors += check_fixture(repo, skill_name)

    if errors:
        emit_block(errors, skill_name)
        return 2  # unreachable — emit_block calls sys.exit(2)

    # Success — stay silent to avoid noise.
    return 0


if __name__ == "__main__":
    sys.exit(main())

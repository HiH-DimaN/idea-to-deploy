#!/usr/bin/env python3
"""
UserPromptSubmit hook — analyzes user prompt for triggers and reminds Claude
to check whether a skill from the Idea-to-Deploy methodology fits.

Reads JSON on stdin: {"prompt": "...", ...}
Outputs JSON on stdout with hookSpecificOutput.additionalContext (injected
back into the model context for the current turn).

Silent (exit 0, no output) if no triggers match — keeps normal turns clean.
"""
import json
import sys


# Each tuple: (regex pattern, hint text). All patterns are matched
# case-insensitively against the lowercased prompt.
TRIGGERS = [
    (
        r"(новый\s+проект|создай\s+проект|хочу\s+проект|стартуем\s+проект|"
        r"начнём\s+проект|приложен|с\s+нуля|новый\s+сайт|новое\s+приложение|"
        r"start\s+a?\s*project|build\s+(it\s+)?from\s+scratch|end-to-end|kickstart)",
        "🔔 Триггер 'проект/приложение' → используй скилл /project (роутер: "
        "/kickstart полный цикл, /blueprint только планирование, /guide промпты "
        "по готовой документации). Вызови через инструмент Skill ПЕРВЫМ.",
    ),
    (
        r"(\bбаг\b|ошибк|не\s+работает|почини|сломал|крашит|падает|"
        r"\bкраш\b|exception|stack\s*trace|стектрейс|стек\s*трейс|"
        r"debug\s+(this|that|it|error|bug|issue|problem)|fix\s+(this\s+)?error)",
        "🔔 Триггер 'баг/ошибка' → используй скилл /debug "
        "(системная отладка через стек/логи/git). Вызови Skill ПЕРВЫМ.",
    ),
    (
        r"(напиши\s+тест|покрой\s+тест|покрой\s+unit|добавь\s+тест|"
        r"генери\s+тест|unit\s*test|integration\s*test|"
        r"add\s+tests?|write\s+tests?|test\s+this|generate\s+tests?)",
        "🔔 Триггер 'тесты' → используй скилл /test или субагента test-generator.",
    ),
    (
        r"(тормозит|медлен|оптимиз|производительност|\bperf\b|bottleneck|"
        r"узкое\s+место|optimize\s+(performance|this|speed)|slow\s+(down|query|endpoint))",
        "🔔 Триггер 'производительность' → используй /perf или perf-analyzer.",
    ),
    (
        r"(отрефактор|рефактор|упрост\w*\s+код|refactor|переписать|"
        r"улучш\w+\s+код)",
        "🔔 Триггер 'рефакторинг' → используй скилл /refactor.",
    ),
    (
        r"(объясни\s+(код|как|что)|как\s+работает|что\s+делает|разбер\w+\s+как|"
        r"explain\s+(this|that|how|what|code)|how\s+does\s+this\s+work|walk\s+me\s+through)",
        "🔔 Триггер 'объясни' → используй /explain (диаграммы + пошаговый разбор).",
    ),
    (
        r"(напиши\s+документ|создай\s+readme|задокумент|api\s+docs?|"
        r"инлайн\s+комментар|сгенери(руй)?\s+(документ|doc|readme)|"
        r"generate\s+(readme|docs?|documentation)|write\s+docs?|add\s+docstrings?)",
        "🔔 Триггер 'документация' → используй /doc или субагента doc-writer.",
    ),
    (
        r"(проверь\s+(код|документ|архитект)|валидац|\breview\b|ревью|"
        r"чек\s+архитектур)",
        "🔔 Триггер 'review' → используй /review или субагента code-reviewer.",
    ),
    (
        r"(спланируй|архитект|blueprint|подготовь\s+документац|спроектируй)",
        "🔔 Триггер 'планирование/архитектура' → используй /blueprint или architect.",
    ),
    (
        r"(сгенери(руй)?\s+(гайд|guide)|сгенерируй\s+промпт|claude\s+code\s+guide|"
        r"пошаговые\s+промпты|generate\s+(a\s+)?guide|step-by-step\s+prompts?)",
        "🔔 Триггер 'guide' → используй /guide (генерирует CLAUDE_CODE_GUIDE.md).",
    ),
    (
        r"(проверь\s+безопасност|security\s*audit|найди\s+уязвимост|"
        r"проверь\s+(auth|секрет|токен)|secrets?\s+check|exposed\s+credentials|"
        r"\bowasp\b|vulnerability\s+scan|перед\s+продакшен\w*\s+проверить)",
        "🔔 Триггер 'security audit' → используй /security-audit (read-only OWASP-style проверка). Вызови Skill ПЕРВЫМ.",
    ),
    (
        r"(накати\s+миграц|применить\s+миграц|обнови\s+схему\s+бд|"
        r"\bmigrate\b|apply\s+migration|run\s+migration|rollback\s+migration|"
        r"alter\s+table|add\s+column|drop\s+table|create\s+index|"
        r"alembic\s+upgrade|prisma\s+migrate|knex\s+migrate|"
        r"перед\s+(any\s+)?ddl|нужно\s+изменить\s+схему)",
        "🔔 Триггер 'миграция БД' → используй /migrate (с backup и rollback path). Вызови Skill ПЕРВЫМ — особенно если речь о production.",
    ),
    (
        r"(аутентифик|авториз|платеж|оплат\w+\s+(сист|инт|api)|"
        r"\bjwt\b|\bcsrf\b|\bxss\b|sql\s*injection)",
        "🔔 Триггер 'auth/payments' → подключи плагин security-guidance ИЛИ используй /security-audit для read-only проверки.",
    ),
    (
        r"(\bui\b|интерфейс|frontend|дизайн\s+компонент|верстк|\bux\b)",
        "🔔 Триггер 'UI/frontend' → подключи плагин frontend-design.",
    ),
    (
        r"(проверь\s+зависимост|проверь\s+пакет|audit\s+deps|"
        r"dependency\s+audit|dep\s+audit|check\s+dependencies|"
        r"найди\s+уязвимые\s+пакет|найди\s+cve\s+в\s+зависимост|"
        r"проверь\s+лицензи|license\s+(check|audit)|"
        r"lockfile\s+audit|supply\s+chain\s+audit|проверка\s+цепочки\s+поставок|"
        r"abandoned\s+packages|заброшенные\s+пакет|устаревшие\s+зависимост|"
        r"\bosv\b|\bghsa\b|github\s+advisory)",
        "🔔 Триггер 'dependency audit' → используй /deps-audit (read-only проверка CVE/лицензий/заброшенных пакетов, тот же enum статусов что у /review). Вызови Skill ПЕРВЫМ.",
    ),
    (
        r"(подготовь\s+к\s+продакшен|готов\s+ли\s+прод|production\s+readiness|"
        r"\bharden\b|hardening|production\s+hardening|"
        r"sre\s+checklist|\brunbook\b|generate\s+runbook|"
        r"нужен\s+мониторинг|настрой\s+prometheus|настрой\s+grafana|"
        r"rate\s+limit|ограничен\w+\s+запрос|throttling|"
        r"graceful\s+shutdown|плавное\s+выключен|"
        r"load\s+test|нагрузочн\w+\s+тест|\bk6\b|"
        r"health\s*check|/healthz|liveness|readiness|"
        r"structured\s+log|structured\s+logs|logs?\s+to\s+json|"
        r"backup\s+strateg|стратеги\w+\s+бэкап)",
        "🔔 Триггер 'production hardening' → используй /harden (рубрика health/logs/metrics/backups/load-test/runbook, генерация артефактов с согласия пользователя). Вызови Skill ПЕРВЫМ.",
    ),
    (
        r"(настрой\s+инфраструктур|provision\s+infrastructure|infra\s+as\s+code|"
        r"\bterraform\b|terraform\s+module|сгенери\w+\s+terraform|"
        r"\bhelm\b|helm\s+chart|k8s\s+manifests?|kubernetes\s+manifests?|"
        r"настрой\s+vault|настрой\s+doppler|secrets?\s+manager|"
        r"provision\s+(servers?|droplet|ec2|instance)|create\s+(droplet|ec2|instance)|"
        r"\btfstate\b|terraform\s+state|backend\s+s3|"
        r"\biac\b|infrastructure\s+as\s+code|инфраструктура\s+как\s+код|"
        r"deploy\s+to\s+(digitalocean|aws|hetzner)|"
        r"managed\s+kubernetes|\bdoks\b|\beks\b|\bgke\b)",
        "🔔 Триггер 'infrastructure-as-code' → используй /infra (Terraform/Helm/secrets для DO/AWS/Hetzner/K8s, remote tfstate с локами для prod). Вызови Skill ПЕРВЫМ.",
    ),
]


def main() -> int:
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return 0

    prompt = (payload or {}).get("prompt") or ""
    if not prompt:
        return 0

    import re

    lp = prompt.lower()
    hints = []
    seen = set()
    for pattern, hint in TRIGGERS:
        if re.search(pattern, lp) and hint not in seen:
            hints.append(hint)
            seen.add(hint)

    if not hints:
        return 0

    context = (
        "[SKILL HINT — Idea-to-Deploy methodology]\n"
        + "\n".join(hints)
        + "\n\nВАЖНО: проверь, подходит ли хоть один скилл. Если да — вызови "
        "его через инструмент Skill ДО Read/Edit/Bash/Write. Если не подходит "
        "— продолжай как обычно. См. ~/projects/.claude/CLAUDE.md раздел "
        "«Автоматическое использование скиллов»."
    )

    out = {
        "hookSpecificOutput": {
            "hookEventName": "UserPromptSubmit",
            "additionalContext": context,
        }
    }
    sys.stdout.write(json.dumps(out, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())

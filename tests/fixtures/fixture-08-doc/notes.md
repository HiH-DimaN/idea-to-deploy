# Manual verification — fixture 08 (/doc)

After running `/doc src/services/payment.py`, verify:

## Style detection
- [ ] If another file in the project has docstrings, the new docstrings match that style (Google / NumPy / reST)
- [ ] If no existing style, Google-style is used (per SKILL.md default)

## Docstring content
- [ ] `calculate_total` has: one-line summary, Args section (items, discount, tax_rate), Returns section
- [ ] `charge_customer` has: one-line summary, Args, Returns, Raises (ValueError when amount <= 0)
- [ ] `_apply_promo_code` has NO docstring (private by leading underscore)

## Behavior preservation
- [ ] No logic lines changed
- [ ] No imports added or removed
- [ ] File still parses as valid Python

## Subagent delegation
- [ ] Skill invokes `doc-writer` subagent as declared in SKILL.md metadata

## Language
- [ ] Docstrings match the language of existing docs in the project (Russian if majority Russian, else English)

## Failures (fill in if any)

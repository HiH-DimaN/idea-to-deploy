# Fixture 08: /doc on an undocumented Python module

## User says

> Задокументируй `src/services/payment.py` — добавь docstrings к публичным функциям в стиле проекта.

## Why this fixture exists

Tests `/doc` end-to-end on a single Python module. Exercises:
- Detection of existing docstring style in the project (Google / NumPy / reST)
- Addition of docstrings to PUBLIC functions only (underscored helpers skipped)
- Preservation of code behavior (no logic changes)
- Matching the project's existing comment language (Russian or English)

## Expected input

`src/services/payment.py`:
```python
from decimal import Decimal

def calculate_total(items, discount=0, tax_rate=Decimal("0.20")):
    subtotal = sum(i.price * i.qty for i in items)
    if discount:
        subtotal *= (1 - discount / 100)
    return subtotal * (1 + tax_rate)

def _apply_promo_code(code, user):
    # private helper — should NOT get a docstring
    return user.promos.get(code)

def charge_customer(customer, amount, idempotency_key):
    if amount <= 0:
        raise ValueError("amount must be positive")
    return {"id": idempotency_key, "status": "charged", "amount": amount}
```

## Expected output

- [ ] `calculate_total` gets a Google-style docstring (project's existing style, if any — else Google default) with Args, Returns
- [ ] `charge_customer` gets a docstring with Args, Returns, Raises (ValueError)
- [ ] `_apply_promo_code` DOES NOT get a docstring (private)
- [ ] No logic changes — only docstring additions
- [ ] The skill invokes `doc-writer` subagent (per its contract)
- [ ] Final report lists: 2 functions documented, 1 skipped (private)

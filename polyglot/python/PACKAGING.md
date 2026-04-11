# Python: Packaging and Service Layout

## Suggested Layout

```text
banking_ledger/
  pyproject.toml
  src/
    banking_ledger/
      __init__.py
      mysql_repo.py      # LedgerRepository from CLIENTS.md
      mongo_projector.py
      settings.py        # pydantic-settings: MYSQL_DSN, MONGO_URI (from env only)
  tests/
    test_debit_idempotency.py
```

## Roles

| Role                    | Notes                                                            |
| ----------------------- | ---------------------------------------------------------------- |
| **Language Maintainer** | Chooses `ruff` + `mypy` strictness for generated SQL helpers.    |
| **SRE**                 | Ensures Gunicorn/Uvicorn worker count matches MySQL pool budget. |

## Configuration

- Never commit `.env` files. Reference vault paths in deployment manifests only.

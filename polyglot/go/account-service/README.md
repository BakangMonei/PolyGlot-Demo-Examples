# Financial Account Service (Go)

**Role:** API Gateway sidecar patterns + reference implementation for MySQL writes.

## Endpoints

- `GET /accounts/{id}`
- `POST /transactions` (requires `Idempotency-Key`, honors `X-Correlation-Id`)
- `GET /reports/{accountId}?format=json|pdf|csv`
- `GET /health`

## Run locally

```bash
export MYSQL_DSN='root:pass@tcp(127.0.0.1:3306)/financial_platform?parseTime=true'
export USE_MEMORY_STORE=false
go run .
```

## Docker

```bash
docker build -t account-go:dev .
docker run --rm -p 7101:7101 -e MYSQL_DSN="$MYSQL_DSN" account-go:dev
```

## Environment

| Variable | Description |
| -------- | ----------- |
| `MYSQL_DSN` | Full DSN (no secrets in git; inject via Secrets Manager in prod) |
| `USE_MEMORY_STORE` | `true` to run without MySQL (CI smoke) |
| `PORT` | Listen port (default 7101) |

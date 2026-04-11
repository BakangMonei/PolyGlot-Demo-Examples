# Dart / Flutter: Security Roles

## Security Reviewer (primary for this folder)

- Prohibit **MySQL/Mongo DSNs** in mobile builds; route commands through a BFF with mTLS or OAuth2.
- Require **certificate pinning** for any direct API from the app when mandated by risk tier.
- Review local **idempotency key** generation (UUID v4 / ULID) for collision resistance and privacy.

## Language Maintainer

- Document which code runs on **server Dart** vs **Flutter client**; never merge the two deployment models in one binary without review.

## SRE

- Rate-limit device-driven retries at the edge to protect `ledger_operations` from storms.

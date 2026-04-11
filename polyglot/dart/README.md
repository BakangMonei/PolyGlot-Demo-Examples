# Dart / Flutter

Mobile-first surfaces and Dart **server** BFFs. Keep DSN secrets off devices; use gateway tokens instead.

## Contents

| Doc | Description |
| --- | ----------- |
| [CLIENTS.md](./CLIENTS.md) | Illustrative `mysql_client` + `mongo_dart` samples |
| [SECURITY.md](./SECURITY.md) | Roles focused on mobile secret handling |

## Roles (this folder)

| Role | Responsibility |
| ---- | ---------------- |
| **Language Maintainer** | Validates VM vs WASM driver constraints. |
| **Security Reviewer** | **Lead** on this folder: no credentials in Flutter assets, attestation for jailbroken devices. |

Global roles: [`../ROLES.md`](../ROLES.md).

## Related

- [`../shared/SAGA_IDEMPOTENCY_INDEX.md`](../shared/SAGA_IDEMPOTENCY_INDEX.md)

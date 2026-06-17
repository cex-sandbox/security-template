# Project Structure Convention

> **Mục đích:** Quy ước về cấu trúc thư mục và file naming cho dự án CEX. AI assistant tham chiếu khi tạo file mới.

---

## Recommended Layout

### Backend (Python example)

```
your-service/
├── .security/          # ← Security config (this template)
├── .github/workflows/             # CI pipelines
├── src/
│   ├── api/                       # HTTP handlers (Flask/FastAPI routes)
│   │   ├── auth.py
│   │   ├── wallet.py
│   │   ├── withdrawal.py
│   │   └── order.py
│   ├── domain/                    # Business logic, pure functions
│   │   ├── wallet.py
│   │   ├── order.py
│   │   └── pricing.py
│   ├── infra/                     # External integrations
│   │   ├── db.py
│   │   ├── cache.py
│   │   ├── blockchain.py
│   │   └── notification.py
│   ├── security/                  # Auth, crypto, validation
│   │   ├── auth.py
│   │   ├── jwt.py
│   │   ├── permissions.py
│   │   └── validation.py
│   └── config.py                  # Config loader (env vars)
├── tests/
│   ├── unit/
│   ├── integration/
│   └── security/                  # Security-specific tests
├── docs/
├── scripts/
├── requirements.txt
└── pyproject.toml
```

### Frontend (React example)

```
your-web/
├── .security/
├── src/
│   ├── api/                       # API client (with auth)
│   ├── components/
│   ├── pages/
│   ├── lib/
│   │   ├── auth.ts                # Token management
│   │   ├── csrf.ts                # CSRF protection
│   │   └── sanitize.ts            # XSS prevention
│   └── config.ts
├── public/
└── package.json
```

### Mobile (React Native / Native)

```
your-mobile/
├── .security/
├── src/
│   ├── screens/
│   ├── components/
│   ├── api/
│   │   ├── client.ts              # Axios với cert pinning
│   │   └── auth.ts
│   ├── lib/
│   │   ├── secureStorage.ts       # Keystore/Keychain wrapper
│   │   ├── biometric.ts
│   │   └── jailbreak.ts           # Detection
│   └── App.tsx
└── android/ios/
```

---

## File Naming Conventions

| Type | Convention | Example |
|---|---|---|
| Python module | snake_case.py | `wallet_service.py` |
| Python class | PascalCase | `class WalletService` |
| JS/TS file | kebab-case.ts | `wallet-service.ts` |
| JS/TS component | PascalCase | `WalletCard.tsx` |
| Constant | UPPER_SNAKE | `MAX_WITHDRAWAL_AMOUNT` |
| Env variable | UPPER_SNAKE | `DATABASE_URL` |
| Config file | kebab-case | `app-config.yml` |
| Test file | mirror source + `_test.py` | `wallet_service_test.py` |

---

## Module Organization Rules

### Separation of Concerns

1. **`api/`** — chỉ HTTP routing và serialization, không có business logic
2. **`domain/`** — business logic pure, không phụ thuộc framework
3. **`infra/`** — external I/O, có thể swap out
4. **`security/`** — cross-cutting concerns, không phụ thuộc domain

### Dependency Direction

```
api → domain → security
       ↓
      infra
```

- `domain` không được import `api` hoặc `infra`
- `infra` không được import `api`
- `security` là leaf — không import gì khác

### Where to Put Code

| Code type | Location |
|---|---|
| Validation | `security/validation.py` |
| Authentication | `security/auth.py` |
| Authorization | `security/permissions.py` |
| DB queries | `infra/db.py` (raw) hoặc `infra/repositories/` |
| Business rules | `domain/` |
| HTTP routes | `api/` |
| External API call | `infra/clients/` |
| Background job | `workers/` |
| Constants | `config.py` hoặc `constants.py` |

---

## Files That Must Exist

Mỗi service repo phải có các file sau:

- `README.md` — quick start, architecture overview
- `CLAUDE.md` — security rules cho AI assistant (từ template này)
- `.gitignore` — exclude `.env`, `.venv`, `node_modules`, build artifacts
- `.dockerignore` — exclude `.env`, `.git`, secrets
- `.pre-commit-config.yaml` — security hooks (từ template này)
- `.github/workflows/security-scan.yml` — CI security pipeline
- `requirements.txt` / `package.json` với version pinning
- `Dockerfile` (nếu containerized) với non-root user

---

## Files That Must NOT Exist

❌ `.env` (chỉ `.env.example` được commit, file `.env` thực phải gitignore)
❌ Credential files: `credentials.json`, `service-account.json`, `*.pem`
❌ Database dump với production data
❌ Build artifacts: `dist/`, `build/`, `node_modules/`, `__pycache__/`
❌ IDE config: `.vscode/`, `.idea/` (trừ khi shareable workspace settings)

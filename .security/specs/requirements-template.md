# Feature Security Requirements — Template

> **Cách dùng:** Copy file này sang `specs/{feature_name}/requirements.md` khi bắt đầu feature mới. Fill từng phần TRƯỚC khi viết code.

---

## Feature Name

`<Feature Name>`

## Stakeholders

- **Product Owner:** [tên]
- **Tech Lead:** [tên]
- **Security Reviewer:** [tên Security Team]

---

## Functional Requirements

### User Stories

EARS format (Easy Approach to Requirements Syntax):

- **WHEN** [trigger], **THE SYSTEM SHALL** [response]
- **WHILE** [state], **THE SYSTEM SHALL** [behavior]
- **IF** [condition] **THEN THE SYSTEM SHALL** [action]

Example:

> **WHEN** user submits withdrawal request with valid amount AND address, **THE SYSTEM SHALL** create a withdrawal record in 'pending' state and deduct the amount from user's available balance.
>
> **IF** user has insufficient balance, **THEN THE SYSTEM SHALL** reject the request with HTTP 400 and message "Insufficient funds".

### Success Criteria

- [ ] Functional tests passing
- [ ] Performance: p99 < 500ms
- [ ] Test coverage > 80%

---

## Security Requirements

### Data Classification

| Data | Classification | Storage | Transmission |
|---|---|---|---|
| User ID | Internal | Encrypted at rest | TLS |
| Amount | Confidential | Encrypted at rest | TLS |
| Address | Confidential | Encrypted at rest | TLS |
| ... | ... | ... | ... |

### Authentication

- [ ] Endpoint requires valid JWT
- [ ] Endpoint requires specific permission: `<permission_name>`
- [ ] Step-up authentication required (re-enter 2FA): YES / NO

### Authorization

- [ ] Resource ownership check: user can only operate on own resources
- [ ] Role-based check: only roles `[X, Y]` allowed
- [ ] Attribute-based check: ... (vd: KYC level >= 2)

### Input Validation

| Field | Type | Required | Constraints |
|---|---|---|---|
| amount | Decimal | Yes | > 0, ≤ MAX_WITHDRAWAL |
| address | string | Yes | currency-specific format regex |
| currency | enum | Yes | one of: BTC, ETH, USDT, ... |
| ... | ... | ... | ... |

### Sensitive Operations

- [ ] Idempotency key required
- [ ] Audit log entry created
- [ ] Notification sent to user (email/SMS/push)
- [ ] Kill-switch can pause this operation

### Compliance

- [ ] PII handling tuân thủ Nghị định 356/2025
- [ ] AML screening required
- [ ] KYC level check
- [ ] Data retention: ___ ngày

---

## Threats Identified (STRIDE)

| Component | Spoofing | Tampering | Repudiation | Info Disclosure | DoS | Privilege Esc |
|---|---|---|---|---|---|---|
| API endpoint | ... | ... | ... | ... | ... | ... |
| DB query | ... | ... | ... | ... | ... | ... |
| Async worker | ... | ... | ... | ... | ... | ... |

Mỗi cell: rủi ro cụ thể + mitigation đã có / cần thêm.

---

## Out of Scope

- ...
- ...

---

## References

- CEX CLAUDE.md
- Confluence: [link to design doc]
- Related PRs: [link]

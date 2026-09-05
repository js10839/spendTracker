# Spending Tracker Working Agreement

## Project Scope

- Follow `Spending-tracker.md` as the product specification and source of truth.
- Keep the application split into `frontend/` (React + Vite + TypeScript + PWA) and `backend/` (FastAPI).
- Build mobile-first responsive layouts and check compact and tall screens for overflow.
- Use `내 지갑` and `카드 추가` in user-facing copy, while keeping `payment_method` in code and database models.

## Implementation

- Do not modify files, install packages, change configuration, or delete anything unless the user explicitly asks Codex to make the change. When the user asks for guidance, explanation, diagnosis, or step-by-step instructions, remain read-only and let the user perform the changes.
- Prefer concise implementations over unnecessary abstractions, one-use helpers, or duplicated constants.
- Preserve boundaries between presentation, domain logic, API access, and persistence.
- Keep guest-mode browser persistence behind a replaceable abstraction so local data can later migrate to the server.
- Verify frontend models and integrations against the actual backend schema and API responses.
- Design ledger-owned APIs under `/ledgers/{ledger_id}/...` as specified in the product plan.
- Keep statement-cycle calculations in a dedicated, well-tested domain module; do not persist derived cycle ranges.
- Make architectural refactors incrementally and preserve existing behavior with focused tests.

## Quality and Safety

- After changes, run formatting, relevant tests, static analysis, and broader regression tests when appropriate.
- Treat user-provided screenshots as the visual source of truth when they conflict with the current UI.
- Treat receipt images and spending data as sensitive. Preserve the private-storage, short-lived URL, image validation, re-encoding, EXIF removal, and PII-safe logging requirements in the product plan.
- Enforce ledger membership authorization on every ledger-owned backend endpoint.
- Do not commit or push changes. The user handles Git operations; recommend a commit message after each meaningful group of changes.

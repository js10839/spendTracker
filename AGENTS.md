# Spending Tracker Working Agreement

## Project Scope

- Follow `Spending-tracker.md` as the product specification and source of truth.
- Target a Flutter iOS/Android app with a FastAPI backend. The existing `frontend/` React/Vite scaffold predates this decision; preserve it until the user explicitly requests a migration or removal.
- Build mobile layouts for compact and tall screens and check for overflow.
- Use `내 지갑` and `카드 추가` in user-facing copy, while keeping `payment_method` in code and database models.

## Implementation

- Do not modify files, install packages, change configuration, or delete anything unless the user explicitly asks Codex to make the change. When the user asks for guidance, explanation, diagnosis, or step-by-step instructions, remain read-only and let the user perform the changes.
- Prefer concise implementations over unnecessary abstractions, one-use helpers, or duplicated constants.
- Preserve boundaries between presentation, domain logic, API access, and persistence.
- Keep guest data in local SQLite behind a replaceable abstraction; make guest-to-account migration idempotent.
- Verify mobile models and integrations against the actual backend schema and API responses.
- Route application data reads and writes through FastAPI; the mobile app may contact Supabase directly for Auth only. Keep provider-specific Auth, Storage, and Gemini code at integration boundaries.
- Use Supabase Auth for credentials. Map app profiles in `public.users` by the same UUID as `auth.users`; never use email as an ownership key.
- Design ledger-owned APIs under `/ledgers/{ledger_id}/...` as specified in the product plan.
- Store money as integer cents. Keep `transactions` for expenses, including manual entries and confirmed receipt items; keep actual income in `income_records` and recurring income rules in `income_sources`.
- Keep statement-cycle calculations in a dedicated, well-tested domain module; do not persist derived cycle ranges.
- Make architectural refactors incrementally and preserve existing behavior with focused tests.

## Backend Boundaries

- `auth/` verifies user tokens; `users/` owns app profiles; `ledgers/` owns ledgers, membership checks, and access control.
- `payment_methods/`, `categories/`, and `transactions/` own their respective CRUD and business rules. Manual expense entry belongs to `transactions/`.
- `receipts/` owns upload, parsing, drafts, categorization rules, and confirmation. Confirmed items become expense transactions through the shared transaction logic; coordinate their creation with the receipt status update.
- `cycles/` calculates statement periods from payment-method closing days and expense transactions. `dashboard/` aggregates persisted data; neither owns the underlying expense records.
- Keep `income_sources` and `income_records` together under `income/`. Their implementation schedule and team owner remain to be agreed; the schema alone does not make them Phase 1 deliverables.
- `db/models/` holds application SQLAlchemy models, and Alembic owns schema migrations. Keep storage and AI clients under `integrations/`; add router, service, repository, and schema files only as their responsibilities become concrete.

## Quality and Safety

- After changes, run formatting, relevant tests, static analysis, and broader regression tests when appropriate.
- Treat user-provided screenshots as the visual source of truth when they conflict with the current UI.
- Treat receipt images and spending data as sensitive. Preserve the private-storage, short-lived URL, image validation, re-encoding, EXIF removal, and PII-safe logging requirements in the product plan.
- Enforce ledger membership authorization on every ledger-owned backend endpoint.
- Do not commit or push changes. The user handles Git operations; recommend a commit message after each meaningful group of changes.

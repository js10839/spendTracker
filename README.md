# Spending Tracker

Spending Tracker is a mobile spending tracker with a Flutter app for iOS and Android and a FastAPI backend.

## Tech Specs

* backend: Python + FastAPI + SQLAlchemy (Supabase PostgreSQL and Auth)
* frontend: Flutter (iOS and Android)

## Main Features (Upcoming)

* Track your spending based on types of your spending(credit, debit, cash, etc)
* Set the calendar that fits best for your spending methods
* Look at your spending dashboard with various visualization
* Parse your receipts to automatically record your detailed spendings
* Wait for more features on Pro mode!!

## Project Architecture

```text
spendTracker/
├── frontend/            # Flutter iOS and Android app
├── backend/             # FastAPI app
└── Spending-tracker.md  # Project plan
```

## Prerequisites

* Flutter 3.47
* Python 3.12
* uv

## Installation

### Frontend
```bash
cd frontend
flutter pub get
```

### Backend
```bash
cd backend
uv sync
```

## Environment Variables

Copy the backend environment example locally:

```bash
cp backend/.env.example backend/.env
```

## How to Run

### Backend
```bash
cd backend
uv run fastapi dev app/main.py
```

Protected backend routes require `SUPABASE_URL` in `backend/.env`. `SUPABASE_JWKS_URL` is optional; it defaults to the project's Auth JWKS endpoint. JWT verification via JWKS requires asymmetric Supabase signing keys.

For routes under `/ledgers/{ledger_id}/...`, depend on `get_user_ledger` from `app.ledgers.dependencies`. It verifies the Bearer token, checks `ledger_members`, and returns 404 for a missing or inaccessible ledger. Ledger creation must add the owner to `ledger_members`. Feature repositories must still filter their own queries by `ledger_id`.

### Frontend
```bash
cd frontend
flutter run
```

## References

For product details, see [Spending-tracker.md](./Spending-tracker.md).

For AI-assisted Flutter work, see the [GJC frontend workflow](./docs/gjc-frontend-workflow.md).

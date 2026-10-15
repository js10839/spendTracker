# Spending Tracker

Spending Tracker is a mobile spending tracker. The existing React frontend is an earlier scaffold; the target app is Flutter for iOS and Android.

## Tech Specs

* backend: Python + FastAPI + SQLAlchemy (Supabase PostgreSQL and Auth)
* target frontend: Flutter (iOS and Android)

## Main Features (Upcoming)

* Track your spending based on types of your spending(credit, debit, cash, etc)
* Set the calendar that fits best for your spending methods
* Look at your spending dashboard with various visualization
* Parse your receipts to automatically record your detailed spendings
* Wait for more features on Pro mode!!

## Project Architecture

```text
spendTracker/
├── frontend/            # React app
├── backend/             # FastAPI app
└── Spending-tracker.md  # Project plan
```

## Prerequisites

* Node.js 24
* Python 3.12
* uv

## Installation

### Frontend
```bash
cd frontend
npm install
```

### Backend
```bash
cd backend
uv sync
```

## Environment Variables

Copy the following local .env.example files

```bash
cp frontend/.env.example frontend/.env
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
npm run dev
```

## References

For product details, see [Spending-tracker.md](./Spending-tracker.md).


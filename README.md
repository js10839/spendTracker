# Spending Tracker

Spending Tracker is a PWA based webapp to solve various issues with current spending tracker services.

## Tech Specs

* backend: Python + FastAPI (Supabase for DB, storage, etc)
* frontend: React(Vite, TS) + PWA

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
├── Spending-tracker.md  # Project plan
└── AGENTS.md            # AI agent working agreement
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

### Frontend
```bash
cd frontend
npm run dev
```

## References

For more details, please check [Spending-tracker.md](./Spending-tracker.md)


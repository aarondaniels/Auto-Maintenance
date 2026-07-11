# Auto Maintenance Tracker

A mobile app for drivers to track vehicle maintenance — gas fillups and service
records (oil changes, brakes, filters, tires, etc.) — with maintenance
reminders and basic stats.

Monorepo:

| Path      | Stack | Purpose |
|-----------|-------|---------|
| [`server/`](server/) | Python · FastAPI · PostgreSQL · JWT | REST API, hosted on Azure App Service |
| [`client/`](client/) | Flutter · Riverpod (iOS & Android) | Mobile app |

## Features (MVP)

- Email/password auth (custom JWT)
- Multiple vehicles per user, with a vehicle switcher
- Log gas fillups (date, odometer, gallons, price) — **MPG auto-computed** between consecutive fillups
- Log service records (type, cost, notes)
- History views for fillups and services
- **Maintenance reminders**: due/overdue per service type, by mileage and/or time, with sensible editable defaults
- **Stats dashboard**: avg MPG, MPG-over-time chart, cost-per-mile, total spend, monthly fuel-vs-service breakdown

Units are US throughout (miles, gallons, USD).

## Quick start

### 1. Backend

```bash
cd server
python3 -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env

# Start Postgres (Docker), or use a local Postgres and edit DATABASE_URL:
docker compose up -d

uvicorn app.main:app --reload
```

API: http://localhost:8000 · Swagger UI: http://localhost:8000/docs

### 2. Flutter client

```bash
cd client
flutter pub get

# iOS simulator (reaches host at localhost):
flutter run

# Android emulator reaches the host at 10.0.2.2 (handled automatically),
# or point at any host/IP explicitly:
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8000
```

See [`server/README.md`](server/README.md) for the full API reference and Azure
deployment notes.

## Status

End-to-end verified locally: backend smoke-tested against Postgres (auth →
vehicles → fillups/MPG → services → reminders → stats), Flutter client passes
`flutter analyze` and its widget test.

## Not yet included (deliberately, for the MVP)

- Alembic migrations (tables auto-create on startup)
- CI/CD pipelines and Azure IaC (Bicep/Terraform)
- Edit (PATCH) UI for existing records — backend endpoints exist; client
  currently supports create + swipe-to-delete
- Push notifications for reminders (status is computed/shown in-app)

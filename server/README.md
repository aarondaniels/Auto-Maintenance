# Auto Maintenance Tracker — Server (FastAPI)

Python/FastAPI backend with custom JWT auth and PostgreSQL.

## Local setup

```bash
cd server
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env   # adjust if needed
```

### Start a Postgres for dev

Option A — Docker (matches Azure's Postgres 16):

```bash
docker compose up -d
```

Option B — local Homebrew Postgres (already installed):

```bash
brew services start postgresql@14
createdb amt
# then set DATABASE_URL in .env to:
#   postgresql+psycopg://<you>@localhost:5432/amt
```

### Run the API

```bash
uvicorn app.main:app --reload
```

- Interactive docs: http://localhost:8000/docs
- Health check: http://localhost:8000/health

Tables are auto-created on startup (MVP convenience). Add Alembic migrations
before production.

## Auth flow

1. `POST /auth/signup` `{ "email", "password" }` → `{ access_token }`
2. `POST /auth/login` (form fields `username`=email, `password`) → `{ access_token }`
3. Send `Authorization: Bearer <token>` on all other endpoints.

## Endpoints

| Area      | Routes |
|-----------|--------|
| Auth      | `POST /auth/signup`, `POST /auth/login`, `GET /auth/me` |
| Vehicles  | `GET/POST /vehicles`, `GET/PATCH/DELETE /vehicles/{id}` |
| Fillups   | `GET/POST /vehicles/{id}/fillups`, `PATCH/DELETE …/fillups/{fid}` |
| Services  | `GET/POST /vehicles/{id}/services`, `PATCH/DELETE …/services/{sid}` |
| Reminders | `GET /vehicles/{id}/reminders/status`, `GET/PUT/DELETE …/reminders/rules` |
| Stats     | `GET /vehicles/{id}/stats` |

## Deploying to Azure (later)

- **Compute:** Azure App Service (Python). Start command:
  `uvicorn app.main:app --host 0.0.0.0 --port 8000`
- **Database:** Azure Database for PostgreSQL — set `DATABASE_URL` as an App
  Setting (use `postgresql+psycopg://USER:PASS@HOST:5432/DB?sslmode=require`).
- Set `JWT_SECRET` to a strong random value in App Settings.

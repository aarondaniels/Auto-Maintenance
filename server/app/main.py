from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .database import Base, engine
from .routers import auth, fillups, reminders, services, stats, vehicles


@asynccontextmanager
async def lifespan(app: FastAPI):
    # MVP convenience: create tables on startup. Swap for Alembic before prod.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(title="Auto Maintenance Tracker API", version="0.1.0", lifespan=lifespan)

# Open CORS for MVP/dev; tighten to the app's origins before production.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(vehicles.router)
app.include_router(fillups.router)
app.include_router(services.router)
app.include_router(reminders.router)
app.include_router(stats.router)


@app.get("/health", tags=["health"])
def health():
    return {"status": "ok"}

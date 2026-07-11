from __future__ import annotations

# Aliased so the `date` *field* name does not shadow the `date` *type* during
# Pydantic's forward-ref resolution.
from datetime import date as DateT
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


# ---- Auth ----
class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8)


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)
    id: int
    email: EmailStr
    created_at: datetime


class Token(BaseModel):
    access_token: str
    token_type: str = "bearer"


# ---- Vehicle ----
class VehicleBase(BaseModel):
    label: str
    make: str | None = None
    model: str | None = None
    year: int | None = None
    current_odometer: int | None = None


class VehicleCreate(VehicleBase):
    pass


class VehicleUpdate(BaseModel):
    label: str | None = None
    make: str | None = None
    model: str | None = None
    year: int | None = None
    current_odometer: int | None = None


class VehicleOut(VehicleBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    user_id: int
    created_at: datetime


# ---- Fillup ----
class FillupBase(BaseModel):
    date: DateT
    odometer: int
    gallons: float = Field(gt=0)
    price_total: float | None = None
    location: str | None = None
    notes: str | None = None


class FillupCreate(FillupBase):
    pass


class FillupUpdate(BaseModel):
    date: DateT | None = None
    odometer: int | None = None
    gallons: float | None = Field(default=None, gt=0)
    price_total: float | None = None
    location: str | None = None
    notes: str | None = None


class FillupOut(FillupBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    vehicle_id: int
    mpg: float | None = None  # computed vs. previous fillup


# ---- Service ----
class ServiceBase(BaseModel):
    date: DateT
    odometer: int
    service_type: str
    cost: float | None = None
    notes: str | None = None


class ServiceCreate(ServiceBase):
    pass


class ServiceUpdate(BaseModel):
    date: DateT | None = None
    odometer: int | None = None
    service_type: str | None = None
    cost: float | None = None
    notes: str | None = None


class ServiceOut(ServiceBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    vehicle_id: int


# ---- Reminder rules / status ----
class ReminderRuleBase(BaseModel):
    service_type: str
    interval_miles: int | None = None
    interval_months: int | None = None


class ReminderRuleCreate(ReminderRuleBase):
    pass


class ReminderRuleOut(ReminderRuleBase):
    model_config = ConfigDict(from_attributes=True)
    id: int
    vehicle_id: int


class ReminderStatus(BaseModel):
    service_type: str
    interval_miles: int | None = None
    interval_months: int | None = None
    last_service_date: DateT | None = None
    last_service_odometer: int | None = None
    miles_until_due: int | None = None
    days_until_due: int | None = None
    status: str  # "ok" | "due_soon" | "overdue" | "unknown"


# ---- Stats ----
class MpgPoint(BaseModel):
    date: DateT
    odometer: int
    mpg: float


class MonthlySpend(BaseModel):
    month: str  # "YYYY-MM"
    fuel: float
    service: float


class StatsOut(BaseModel):
    total_fillups: int
    total_services: int
    total_fuel_cost: float
    total_service_cost: float
    total_spend: float
    avg_mpg: float | None = None
    cost_per_mile: float | None = None
    mpg_series: list[MpgPoint]
    monthly_spend: list[MonthlySpend]

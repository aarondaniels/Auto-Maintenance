from collections import defaultdict

from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_vehicle
from ..models import FillupRecord, ServiceRecord, Vehicle
from ..schemas import MonthlySpend, MpgPoint, StatsOut

router = APIRouter(prefix="/vehicles/{vehicle_id}/stats", tags=["stats"])


@router.get("", response_model=StatsOut)
def vehicle_stats(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    fillups = list(
        db.scalars(
            select(FillupRecord)
            .where(FillupRecord.vehicle_id == vehicle.id)
            .order_by(FillupRecord.odometer)
        ).all()
    )
    services = list(
        db.scalars(
            select(ServiceRecord).where(ServiceRecord.vehicle_id == vehicle.id)
        ).all()
    )

    total_fuel_cost = sum(f.price_total or 0.0 for f in fillups)
    total_service_cost = sum(s.cost or 0.0 for s in services)

    # MPG between consecutive fillups (by odometer).
    mpg_series: list[MpgPoint] = []
    total_miles = 0
    total_gallons_used = 0.0
    prev_odo: int | None = None
    for f in fillups:
        if prev_odo is not None and f.gallons > 0:
            miles = f.odometer - prev_odo
            if miles > 0:
                mpg_series.append(
                    MpgPoint(date=f.date, odometer=f.odometer, mpg=round(miles / f.gallons, 2))
                )
                total_miles += miles
                total_gallons_used += f.gallons
        prev_odo = f.odometer

    avg_mpg = round(total_miles / total_gallons_used, 2) if total_gallons_used else None
    total_spend = total_fuel_cost + total_service_cost
    cost_per_mile = round(total_spend / total_miles, 4) if total_miles else None

    # Monthly spend, fuel vs. service.
    buckets: dict[str, dict[str, float]] = defaultdict(lambda: {"fuel": 0.0, "service": 0.0})
    for f in fillups:
        buckets[f.date.strftime("%Y-%m")]["fuel"] += f.price_total or 0.0
    for s in services:
        buckets[s.date.strftime("%Y-%m")]["service"] += s.cost or 0.0
    monthly_spend = [
        MonthlySpend(month=m, fuel=round(v["fuel"], 2), service=round(v["service"], 2))
        for m, v in sorted(buckets.items())
    ]

    return StatsOut(
        total_fillups=len(fillups),
        total_services=len(services),
        total_fuel_cost=round(total_fuel_cost, 2),
        total_service_cost=round(total_service_cost, 2),
        total_spend=round(total_spend, 2),
        avg_mpg=avg_mpg,
        cost_per_mile=cost_per_mile,
        mpg_series=mpg_series,
        monthly_spend=monthly_spend,
    )

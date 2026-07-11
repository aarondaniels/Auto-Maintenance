from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_vehicle
from ..models import ReminderRule, ServiceRecord, Vehicle
from ..schemas import ReminderRuleCreate, ReminderRuleOut, ReminderStatus

router = APIRouter(prefix="/vehicles/{vehicle_id}/reminders", tags=["reminders"])

# Sensible defaults applied when a vehicle has no custom rule for a type.
DEFAULT_INTERVALS: dict[str, dict[str, int]] = {
    "oil change": {"interval_miles": 5000, "interval_months": 6},
    "tires": {"interval_miles": 50000, "interval_months": 72},
    "brakes": {"interval_miles": 25000, "interval_months": 36},
    "filters": {"interval_miles": 15000, "interval_months": 12},
}

DUE_SOON_MILES = 500
DUE_SOON_DAYS = 30


def _months_to_days(months: int) -> int:
    return int(months * 30.44)


def _compute_status(
    service_type: str,
    interval_miles: int | None,
    interval_months: int | None,
    last: ServiceRecord | None,
    current_odometer: int | None,
    today: date,
) -> ReminderStatus:
    miles_until = None
    days_until = None

    if last is not None:
        if interval_miles and current_odometer is not None:
            due_odo = last.odometer + interval_miles
            miles_until = due_odo - current_odometer
        if interval_months:
            due_date = date.fromordinal(
                last.date.toordinal() + _months_to_days(interval_months)
            )
            days_until = (due_date - today).days

    status = "unknown"
    if last is None:
        status = "unknown"
    else:
        overdue = (miles_until is not None and miles_until < 0) or (
            days_until is not None and days_until < 0
        )
        due_soon = (miles_until is not None and miles_until <= DUE_SOON_MILES) or (
            days_until is not None and days_until <= DUE_SOON_DAYS
        )
        if overdue:
            status = "overdue"
        elif due_soon:
            status = "due_soon"
        else:
            status = "ok"

    return ReminderStatus(
        service_type=service_type,
        interval_miles=interval_miles,
        interval_months=interval_months,
        last_service_date=last.date if last else None,
        last_service_odometer=last.odometer if last else None,
        miles_until_due=miles_until,
        days_until_due=days_until,
        status=status,
    )


@router.get("/rules", response_model=list[ReminderRuleOut])
def list_rules(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    return db.scalars(
        select(ReminderRule).where(ReminderRule.vehicle_id == vehicle.id)
    ).all()


@router.put("/rules", response_model=ReminderRuleOut)
def upsert_rule(
    payload: ReminderRuleCreate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    """Create or replace the interval rule for a service type on this vehicle."""
    rule = db.scalar(
        select(ReminderRule).where(
            ReminderRule.vehicle_id == vehicle.id,
            ReminderRule.service_type == payload.service_type,
        )
    )
    if rule is None:
        rule = ReminderRule(vehicle_id=vehicle.id, **payload.model_dump())
        db.add(rule)
    else:
        rule.interval_miles = payload.interval_miles
        rule.interval_months = payload.interval_months
    db.commit()
    db.refresh(rule)
    return rule


@router.delete("/rules/{rule_id}", status_code=204)
def delete_rule(
    rule_id: int,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    rule = db.get(ReminderRule, rule_id)
    if rule is None or rule.vehicle_id != vehicle.id:
        raise HTTPException(status_code=404, detail="Rule not found")
    db.delete(rule)
    db.commit()


@router.get("/status", response_model=list[ReminderStatus])
def reminder_status(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    """Due/overdue status per service type, using custom rules or defaults."""
    rules = db.scalars(
        select(ReminderRule).where(ReminderRule.vehicle_id == vehicle.id)
    ).all()
    rule_by_type = {r.service_type.lower(): r for r in rules}

    service_types = set(DEFAULT_INTERVALS) | set(rule_by_type)
    today = date.today()
    results: list[ReminderStatus] = []

    for stype in sorted(service_types):
        rule = rule_by_type.get(stype)
        if rule is not None:
            miles = rule.interval_miles
            months = rule.interval_months
        else:
            defaults = DEFAULT_INTERVALS.get(stype, {})
            miles = defaults.get("interval_miles")
            months = defaults.get("interval_months")

        last = db.scalar(
            select(ServiceRecord)
            .where(
                ServiceRecord.vehicle_id == vehicle.id,
                ServiceRecord.service_type.ilike(stype),
            )
            .order_by(ServiceRecord.odometer.desc())
            .limit(1)
        )
        results.append(
            _compute_status(
                stype, miles, months, last, vehicle.current_odometer, today
            )
        )
    return results

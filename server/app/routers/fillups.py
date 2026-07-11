from fastapi import APIRouter, Depends
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_vehicle
from ..models import FillupRecord, Vehicle
from ..schemas import FillupCreate, FillupOut, FillupUpdate

router = APIRouter(prefix="/vehicles/{vehicle_id}/fillups", tags=["fillups"])


def _with_mpg(fillups: list[FillupRecord]) -> list[FillupOut]:
    """Compute MPG for each fillup vs. the previous one (by odometer).

    MPG = miles driven since previous fillup / gallons in THIS fillup.
    The earliest fillup has no previous reading, so its mpg is None.
    """
    ordered = sorted(fillups, key=lambda f: (f.odometer, f.id))
    out: list[FillupOut] = []
    prev_odo: int | None = None
    for f in ordered:
        mpg = None
        if prev_odo is not None and f.gallons > 0:
            miles = f.odometer - prev_odo
            if miles > 0:
                mpg = round(miles / f.gallons, 2)
        item = FillupOut.model_validate(f)
        item.mpg = mpg
        out.append(item)
        prev_odo = f.odometer
    return out


@router.get("", response_model=list[FillupOut])
def list_fillups(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    rows = db.scalars(
        select(FillupRecord).where(FillupRecord.vehicle_id == vehicle.id)
    ).all()
    # Return newest-first for display, but MPG is computed in odometer order.
    return sorted(_with_mpg(list(rows)), key=lambda f: f.odometer, reverse=True)


@router.post("", response_model=FillupOut, status_code=201)
def create_fillup(
    payload: FillupCreate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    fillup = FillupRecord(vehicle_id=vehicle.id, **payload.model_dump())
    db.add(fillup)
    # Keep the vehicle's current odometer in sync with the latest reading.
    if vehicle.current_odometer is None or fillup.odometer > vehicle.current_odometer:
        vehicle.current_odometer = fillup.odometer
    db.commit()
    db.refresh(fillup)
    rows = db.scalars(
        select(FillupRecord).where(FillupRecord.vehicle_id == vehicle.id)
    ).all()
    return next(f for f in _with_mpg(list(rows)) if f.id == fillup.id)


@router.patch("/{fillup_id}", response_model=FillupOut)
def update_fillup(
    fillup_id: int,
    payload: FillupUpdate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    fillup = db.get(FillupRecord, fillup_id)
    if fillup is None or fillup.vehicle_id != vehicle.id:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Fillup not found")
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(fillup, field, value)
    db.commit()
    rows = db.scalars(
        select(FillupRecord).where(FillupRecord.vehicle_id == vehicle.id)
    ).all()
    return next(f for f in _with_mpg(list(rows)) if f.id == fillup.id)


@router.delete("/{fillup_id}", status_code=204)
def delete_fillup(
    fillup_id: int,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    fillup = db.get(FillupRecord, fillup_id)
    if fillup is None or fillup.vehicle_id != vehicle.id:
        from fastapi import HTTPException

        raise HTTPException(status_code=404, detail="Fillup not found")
    db.delete(fillup)
    db.commit()

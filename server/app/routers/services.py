from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_owned_vehicle
from ..models import ServiceRecord, Vehicle
from ..schemas import ServiceCreate, ServiceOut, ServiceUpdate

router = APIRouter(prefix="/vehicles/{vehicle_id}/services", tags=["services"])


def _get_owned_service(
    service_id: int, vehicle: Vehicle, db: Session
) -> ServiceRecord:
    service = db.get(ServiceRecord, service_id)
    if service is None or service.vehicle_id != vehicle.id:
        raise HTTPException(status_code=404, detail="Service record not found")
    return service


@router.get("", response_model=list[ServiceOut])
def list_services(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    return db.scalars(
        select(ServiceRecord)
        .where(ServiceRecord.vehicle_id == vehicle.id)
        .order_by(ServiceRecord.date.desc(), ServiceRecord.id.desc())
    ).all()


@router.post("", response_model=ServiceOut, status_code=201)
def create_service(
    payload: ServiceCreate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    service = ServiceRecord(vehicle_id=vehicle.id, **payload.model_dump())
    db.add(service)
    if vehicle.current_odometer is None or service.odometer > vehicle.current_odometer:
        vehicle.current_odometer = service.odometer
    db.commit()
    db.refresh(service)
    return service


@router.patch("/{service_id}", response_model=ServiceOut)
def update_service(
    service_id: int,
    payload: ServiceUpdate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    service = _get_owned_service(service_id, vehicle, db)
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(service, field, value)
    db.commit()
    db.refresh(service)
    return service


@router.delete("/{service_id}", status_code=204)
def delete_service(
    service_id: int,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    service = _get_owned_service(service_id, vehicle, db)
    db.delete(service)
    db.commit()

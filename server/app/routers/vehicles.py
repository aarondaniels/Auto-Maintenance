from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from ..database import get_db
from ..deps import get_current_user, get_owned_vehicle
from ..models import User, Vehicle, VehicleMember
from ..schemas import (
    VehicleCreate,
    VehicleMemberCreate,
    VehicleMemberOut,
    VehicleOut,
    VehicleUpdate,
)

router = APIRouter(prefix="/vehicles", tags=["vehicles"])


@router.get("", response_model=list[VehicleOut])
def list_vehicles(
    db: Session = Depends(get_db), user: User = Depends(get_current_user)
):
    accessible_vehicle_ids = select(VehicleMember.vehicle_id).where(
        VehicleMember.user_id == user.id
    )
    return db.scalars(
        select(Vehicle)
        .where(
            or_(Vehicle.user_id == user.id, Vehicle.id.in_(accessible_vehicle_ids))
        )
        .distinct()
        .order_by(Vehicle.id)
    ).all()


@router.post("", response_model=VehicleOut, status_code=201)
def create_vehicle(
    payload: VehicleCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    vehicle = Vehicle(user_id=user.id, **payload.model_dump())
    db.add(vehicle)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.get("/{vehicle_id}/members", response_model=list[VehicleMemberOut])
def list_vehicle_members(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    return db.scalars(
        select(VehicleMember)
        .where(VehicleMember.vehicle_id == vehicle.id)
        .order_by(VehicleMember.id)
    ).all()


@router.post(
    "/{vehicle_id}/members", response_model=VehicleMemberOut, status_code=201
)
def add_vehicle_member(
    vehicle_id: int,
    payload: VehicleMemberCreate,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
    vehicle: Vehicle = Depends(get_owned_vehicle),
):
    if vehicle.user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the owner can manage sharing")

    target_user = db.scalar(select(User).where(User.email == payload.email))
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    if target_user.id == user.id:
        raise HTTPException(status_code=409, detail="User already has access")

    existing = db.scalar(
        select(VehicleMember).where(
            VehicleMember.vehicle_id == vehicle.id,
            VehicleMember.user_id == target_user.id,
        )
    )
    if existing is not None:
        raise HTTPException(status_code=409, detail="User already has access")

    member = VehicleMember(
        vehicle_id=vehicle.id,
        user_id=target_user.id,
        role=payload.role or "editor",
    )
    db.add(member)
    db.commit()
    db.refresh(member)
    return member


@router.delete("/{vehicle_id}/members/{member_user_id}", status_code=204)
def remove_vehicle_member(
    member_user_id: int,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
):
    if vehicle.user_id != user.id:
        raise HTTPException(status_code=403, detail="Only the owner can manage sharing")

    member = db.scalar(
        select(VehicleMember).where(
            VehicleMember.vehicle_id == vehicle.id,
            VehicleMember.user_id == member_user_id,
        )
    )
    if member is None:
        raise HTTPException(status_code=404, detail="Member not found")
    if member.user_id == vehicle.user_id:
        raise HTTPException(status_code=400, detail="Cannot remove the vehicle owner")

    db.delete(member)
    db.commit()


@router.get("/{vehicle_id}", response_model=VehicleOut)
def get_vehicle(vehicle: Vehicle = Depends(get_owned_vehicle)):
    return vehicle


@router.patch("/{vehicle_id}", response_model=VehicleOut)
def update_vehicle(
    payload: VehicleUpdate,
    vehicle: Vehicle = Depends(get_owned_vehicle),
    db: Session = Depends(get_db),
):
    for field, value in payload.model_dump(exclude_unset=True).items():
        setattr(vehicle, field, value)
    db.commit()
    db.refresh(vehicle)
    return vehicle


@router.delete("/{vehicle_id}", status_code=204)
def delete_vehicle(
    vehicle: Vehicle = Depends(get_owned_vehicle), db: Session = Depends(get_db)
):
    db.delete(vehicle)
    db.commit()

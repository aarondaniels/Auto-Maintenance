from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from sqlalchemy.orm import Session

from sqlalchemy import select

from .database import get_db
from .models import User, Vehicle, VehicleMember
from .security import decode_token

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="auth/login")

_credentials_exc = HTTPException(
    status_code=status.HTTP_401_UNAUTHORIZED,
    detail="Could not validate credentials",
    headers={"WWW-Authenticate": "Bearer"},
)


def get_current_user(
    token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)
) -> User:
    subject = decode_token(token)
    if subject is None:
        raise _credentials_exc
    user = db.get(User, int(subject))
    if user is None:
        raise _credentials_exc
    return user


def get_owned_vehicle(
    vehicle_id: int,
    db: Session = Depends(get_db),
    user: User = Depends(get_current_user),
) -> Vehicle:
    vehicle = db.get(Vehicle, vehicle_id)
    if vehicle is None:
        raise HTTPException(status_code=404, detail="Vehicle not found")

    is_owner = vehicle.user_id == user.id
    is_member = (
        db.scalar(
            select(VehicleMember).where(
                VehicleMember.vehicle_id == vehicle.id,
                VehicleMember.user_id == user.id,
            )
        )
        is not None
    )
    if not (is_owner or is_member):
        raise HTTPException(status_code=404, detail="Vehicle not found")
    return vehicle

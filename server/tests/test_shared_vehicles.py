import os
import unittest

os.environ.setdefault("DATABASE_URL", "sqlite:///:memory:")

from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker
from sqlalchemy.pool import StaticPool

from app import database as database_module
from app.security import create_access_token, hash_password


database_module.engine = create_engine(
    "sqlite://",
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
database_module.SessionLocal = sessionmaker(
    bind=database_module.engine, autoflush=False, autocommit=False
)

from app.database import SessionLocal, engine
from app.main import app
from app.models import Base, User, Vehicle, VehicleMember


class SharedVehicleApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        Base.metadata.drop_all(bind=engine)
        Base.metadata.create_all(bind=engine)

    def setUp(self):
        Base.metadata.drop_all(bind=engine)
        Base.metadata.create_all(bind=engine)
        self.client = TestClient(app)

    def _create_user(self, email: str, password: str = "password123") -> User:
        with SessionLocal() as db:
            user = User(email=email, hashed_password=hash_password(password))
            db.add(user)
            db.commit()
            db.refresh(user)
            return user

    def _auth_headers(self, user_id: int) -> dict[str, str]:
        return {"Authorization": f"Bearer {create_access_token(str(user_id))}"}

    def test_partner_can_view_and_update_shared_vehicle(self):
        owner = self._create_user("owner@example.com")
        partner = self._create_user("partner@example.com")

        owner_headers = self._auth_headers(owner.id)
        partner_headers = self._auth_headers(partner.id)

        create_vehicle_response = self.client.post(
            "/vehicles",
            json={"label": "Honda Civic", "make": "Honda", "model": "Civic"},
            headers=owner_headers,
        )
        self.assertEqual(create_vehicle_response.status_code, 201)
        vehicle_id = create_vehicle_response.json()["id"]

        share_response = self.client.post(
            f"/vehicles/{vehicle_id}/members",
            json={"email": partner.email},
            headers=owner_headers,
        )
        self.assertEqual(share_response.status_code, 201)

        list_response = self.client.get("/vehicles", headers=partner_headers)
        self.assertEqual(list_response.status_code, 200)
        vehicle_ids = [vehicle["id"] for vehicle in list_response.json()]
        self.assertIn(vehicle_id, vehicle_ids)

        fillup_response = self.client.post(
            f"/vehicles/{vehicle_id}/fillups",
            json={
                "date": "2026-07-10",
                "odometer": 12000,
                "gallons": 12.5,
                "price_total": 45.5,
                "location": "Shell",
            },
            headers=partner_headers,
        )
        self.assertEqual(fillup_response.status_code, 201)
        self.assertEqual(fillup_response.json()["location"], "Shell")


if __name__ == "__main__":
    unittest.main()

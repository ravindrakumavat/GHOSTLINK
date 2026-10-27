from typing import Optional

from sqlalchemy import asc, desc
from sqlalchemy.orm import Session

from app.models import SosRequest
from app.schemas import SosRequestCreate
from app.enums import EmergencyLevel, SosStatus
from app.priority import compute_priority


def create_sos_request(db: Session, payload: SosRequestCreate) -> SosRequest:
    priority_score, priority_level = compute_priority(
        injury_type=payload.injury_type,
        emergency_level=payload.emergency_level,
        victim_count=payload.victim_count,
        battery_percentage=payload.battery_percentage,
    )

    db_obj = SosRequest(
        victim_name=payload.victim_name,
        injury_type=payload.injury_type,
        victim_count=payload.victim_count,
        emergency_level=payload.emergency_level,
        latitude=payload.latitude,
        longitude=payload.longitude,
        battery_percentage=payload.battery_percentage,
        device_id=payload.device_id,
        priority_score=priority_score,
        priority_level=priority_level,
        status=SosStatus.PENDING,
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj


def get_sos_request(db: Session, uuid: str) -> Optional[SosRequest]:
    return db.query(SosRequest).filter(SosRequest.uuid == uuid).first()


def list_sos_requests(
    db: Session,
    status: Optional[SosStatus] = None,
    emergency_level: Optional[EmergencyLevel] = None,
    sort: str = "newest",
) -> list[SosRequest]:
    query = db.query(SosRequest)

    if status is not None:
        query = query.filter(SosRequest.status == status)
    if emergency_level is not None:
        query = query.filter(SosRequest.emergency_level == emergency_level)

    order_col = SosRequest.created_at
    query = query.order_by(desc(order_col) if sort == "newest" else asc(order_col))

    return query.all()


def update_sos_status(
    db: Session, uuid: str, new_status: SosStatus
) -> Optional[SosRequest]:
    db_obj = get_sos_request(db, uuid)
    if db_obj is None:
        return None
    db_obj.status = new_status
    db.commit()
    db.refresh(db_obj)
    return db_obj


def delete_sos_request(db: Session, uuid: str) -> bool:
    db_obj = get_sos_request(db, uuid)
    if db_obj is None:
        return False
    db.delete(db_obj)
    db.commit()
    return True

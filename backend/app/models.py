import uuid as uuid_lib
from datetime import datetime, timezone

from sqlalchemy import String, Integer, Float, DateTime, Enum as SAEnum
from sqlalchemy.orm import Mapped, mapped_column

from app.database import Base
from app.enums import InjuryType, EmergencyLevel, PriorityLevel, SosStatus


def _new_uuid() -> str:
    return str(uuid_lib.uuid4())


def _utcnow() -> datetime:
    return datetime.now(timezone.utc)


class SosRequest(Base):
    __tablename__ = "sos_requests"

    uuid: Mapped[str] = mapped_column(
        String(36), primary_key=True, default=_new_uuid, index=True
    )
    victim_name: Mapped[str] = mapped_column(String(255), nullable=False)
    injury_type: Mapped[InjuryType] = mapped_column(
        SAEnum(InjuryType, native_enum=False, length=32), nullable=False
    )
    victim_count: Mapped[int] = mapped_column(Integer, nullable=False)
    emergency_level: Mapped[EmergencyLevel] = mapped_column(
        SAEnum(EmergencyLevel, native_enum=False, length=16), nullable=False
    )
    latitude: Mapped[float] = mapped_column(Float, nullable=False)
    longitude: Mapped[float] = mapped_column(Float, nullable=False)
    battery_percentage: Mapped[int] = mapped_column(Integer, nullable=False)
    device_id: Mapped[str] = mapped_column(String(255), nullable=False)

    priority_score: Mapped[float] = mapped_column(Float, nullable=False)
    priority_level: Mapped[PriorityLevel] = mapped_column(
        SAEnum(PriorityLevel, native_enum=False, length=16), nullable=False
    )
    status: Mapped[SosStatus] = mapped_column(
        SAEnum(SosStatus, native_enum=False, length=16),
        nullable=False,
        default=SosStatus.PENDING,
    )

    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow
    )
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, default=_utcnow, onupdate=_utcnow
    )

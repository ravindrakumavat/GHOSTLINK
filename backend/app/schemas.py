from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.enums import InjuryType, EmergencyLevel, PriorityLevel, SosStatus


class SosRequestCreate(BaseModel):
    victim_name: str = Field(..., min_length=1, max_length=255, examples=["Ravi Kumar"])
    injury_type: InjuryType
    victim_count: int = Field(..., ge=1, examples=[1])
    emergency_level: EmergencyLevel
    latitude: float = Field(..., ge=-90, le=90, examples=[18.6298])
    longitude: float = Field(..., ge=-180, le=180, examples=[73.7997])
    battery_percentage: int = Field(..., ge=0, le=100, examples=[76])
    device_id: str = Field(..., min_length=1, max_length=255, examples=["device-a1b2c3"])


class SosRequest(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    uuid: str
    victim_name: str
    injury_type: InjuryType
    victim_count: int
    emergency_level: EmergencyLevel
    latitude: float
    longitude: float
    battery_percentage: int
    device_id: str
    priority_score: float
    priority_level: PriorityLevel
    status: SosStatus
    created_at: datetime
    updated_at: datetime


class SosStatusUpdate(BaseModel):
    status: SosStatus


class ErrorResponse(BaseModel):
    error: str
    message: str

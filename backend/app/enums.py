"""
Enum definitions for the ResQMesh AI SOS API.

These values are frozen by the OpenAPI contract. Do not add, remove,
or rename any member — every layer (database, ORM, Pydantic schemas,
frontend) depends on these exact strings.
"""

import enum


class InjuryType(str, enum.Enum):
    CRITICAL = "Critical"
    SERIOUS = "Serious"
    MINOR = "Minor"
    PREGNANT = "Pregnant"
    CHILD = "Child"


class EmergencyLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class PriorityLevel(str, enum.Enum):
    LOW = "LOW"
    MEDIUM = "MEDIUM"
    HIGH = "HIGH"


class SosStatus(str, enum.Enum):
    PENDING = "PENDING"
    RECEIVED = "RECEIVED"
    ASSIGNED = "ASSIGNED"
    RESCUED = "RESCUED"

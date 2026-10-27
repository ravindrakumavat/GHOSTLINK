"""
Priority engine for ResQMesh AI.

Computes a numeric priority_score (0-100) and a categorical
priority_level (LOW/MEDIUM/HIGH) for an SOS request, based on:
  - injury_type severity
  - emergency_level reported by the victim/device
  - victim_count (more victims -> higher urgency)
  - battery_percentage (a dying device is more urgent to reach)

This lives entirely on the backend so results are deterministic and
consistent regardless of which client submitted the request. Because
injury_type is a strict enum (not free text), this mapping is exact
and never has to guess at variant spellings.
"""

from app.enums import InjuryType, EmergencyLevel, PriorityLevel

# Points awarded per injury type (max 40)
_INJURY_WEIGHTS = {
    InjuryType.CRITICAL: 40,
    InjuryType.PREGNANT: 35,
    InjuryType.CHILD: 35,
    InjuryType.SERIOUS: 25,
    InjuryType.MINOR: 10,
}

# Points awarded per reported emergency level (max 30)
_EMERGENCY_WEIGHTS = {
    EmergencyLevel.HIGH: 30,
    EmergencyLevel.MEDIUM: 15,
    EmergencyLevel.LOW: 5,
}

# Victim count contributes up to 20 points (2 points per victim, capped at 10 victims)
_VICTIM_COUNT_POINTS_PER_HEAD = 2
_VICTIM_COUNT_CAP = 10

# Battery urgency contributes up to 15 points (a low-battery device may go
# offline before a rescue team arrives)
_BATTERY_CRITICAL_THRESHOLD = 20
_BATTERY_LOW_THRESHOLD = 50
_BATTERY_CRITICAL_POINTS = 15
_BATTERY_LOW_POINTS = 5

_SCORE_MIN = 0.0
_SCORE_MAX = 100.0

_HIGH_THRESHOLD = 70.0
_MEDIUM_THRESHOLD = 40.0


def compute_priority(
    injury_type: InjuryType,
    emergency_level: EmergencyLevel,
    victim_count: int,
    battery_percentage: int,
) -> tuple[float, PriorityLevel]:
    """Returns (priority_score, priority_level) for the given inputs."""

    score = 0.0
    score += _INJURY_WEIGHTS[injury_type]
    score += _EMERGENCY_WEIGHTS[emergency_level]

    capped_victims = min(max(victim_count, 0), _VICTIM_COUNT_CAP)
    score += capped_victims * _VICTIM_COUNT_POINTS_PER_HEAD

    if battery_percentage <= _BATTERY_CRITICAL_THRESHOLD:
        score += _BATTERY_CRITICAL_POINTS
    elif battery_percentage <= _BATTERY_LOW_THRESHOLD:
        score += _BATTERY_LOW_POINTS

    score = max(_SCORE_MIN, min(_SCORE_MAX, score))

    if score >= _HIGH_THRESHOLD:
        level = PriorityLevel.HIGH
    elif score >= _MEDIUM_THRESHOLD:
        level = PriorityLevel.MEDIUM
    else:
        level = PriorityLevel.LOW

    return round(score, 2), level

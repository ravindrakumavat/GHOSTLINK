from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status as http_status
from sqlalchemy.orm import Session

from app import crud
from app.database import get_db
from app.enums import EmergencyLevel, SosStatus
from app.schemas import SosRequest, SosRequestCreate, SosStatusUpdate, ErrorResponse

router = APIRouter(tags=["SOS"])


def _not_found_error(uuid: str) -> HTTPException:
    return HTTPException(
        status_code=http_status.HTTP_404_NOT_FOUND,
        detail={
            "error": "NOT_FOUND",
            "message": f"SOS request with uuid '{uuid}' was not found.",
        },
    )


@router.post(
    "/sos",
    response_model=SosRequest,
    status_code=http_status.HTTP_201_CREATED,
    responses={
        400: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
    summary="Create a new SOS request",
)
def create_sos(payload: SosRequestCreate, db: Session = Depends(get_db)):
    return crud.create_sos_request(db, payload)


@router.get(
    "/sos",
    response_model=list[SosRequest],
    responses={500: {"model": ErrorResponse}},
    summary="List all SOS requests",
)
def list_sos(
    status: Optional[SosStatus] = Query(default=None),
    emergency_level: Optional[EmergencyLevel] = Query(default=None),
    sort: str = Query(default="newest", pattern="^(newest|oldest)$"),
    db: Session = Depends(get_db),
):
    return crud.list_sos_requests(db, status=status, emergency_level=emergency_level, sort=sort)


@router.get(
    "/sos/{uuid}",
    response_model=SosRequest,
    responses={
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
    summary="Get a single SOS request by UUID",
)
def get_sos(uuid: str, db: Session = Depends(get_db)):
    db_obj = crud.get_sos_request(db, uuid)
    if db_obj is None:
        raise _not_found_error(uuid)
    return db_obj


@router.put(
    "/sos/{uuid}/status",
    response_model=SosRequest,
    responses={
        400: {"model": ErrorResponse},
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
    summary="Update the status of an SOS request",
)
def update_status(uuid: str, payload: SosStatusUpdate, db: Session = Depends(get_db)):
    db_obj = crud.update_sos_status(db, uuid, payload.status)
    if db_obj is None:
        raise _not_found_error(uuid)
    return db_obj


@router.delete(
    "/sos/{uuid}",
    status_code=http_status.HTTP_204_NO_CONTENT,
    responses={
        404: {"model": ErrorResponse},
        500: {"model": ErrorResponse},
    },
    summary="Delete an SOS request by UUID",
)
def delete_sos(uuid: str, db: Session = Depends(get_db)):
    deleted = crud.delete_sos_request(db, uuid)
    if not deleted:
        raise _not_found_error(uuid)
    return None

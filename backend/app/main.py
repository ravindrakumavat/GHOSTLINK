from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.config import API_PREFIX, APP_TITLE, APP_VERSION, APP_DESCRIPTION
from app.database import Base, engine
from app.routers import sos


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Creates resqmesh.db and all tables automatically if they don't exist yet.
    Base.metadata.create_all(bind=engine)
    yield


app = FastAPI(
    title=APP_TITLE,
    version=APP_VERSION,
    description=APP_DESCRIPTION,
    lifespan=lifespan,
)

# Open CORS for local development against the Flutter client. Tighten this
# for a production deployment.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    """
    Normalizes every HTTPException into the contract's ErrorResponse shape:
    {"error": "...", "message": "..."}
    Route handlers already raise with a dict detail in this shape; this
    handler also covers any exception raised elsewhere (e.g. FastAPI's own
    404 for an unmatched route).
    """
    if isinstance(exc.detail, dict) and "error" in exc.detail and "message" in exc.detail:
        content = exc.detail
    else:
        content = {"error": "HTTP_ERROR", "message": str(exc.detail)}
    return JSONResponse(status_code=exc.status_code, content=content)


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    """
    The contract specifies 400 for invalid payloads (not FastAPI's default
    422), so request/body validation errors are remapped here.
    """
    first_error = exc.errors()[0] if exc.errors() else {}
    loc_parts = [
        str(loc) for loc in first_error.get("loc", [])
        if loc != "body" and not isinstance(loc, int)
    ]
    field = ".".join(loc_parts)
    reason = first_error.get("msg", "Invalid request payload.")
    message = f"{field}: {reason}" if field else reason
    return JSONResponse(
        status_code=400,
        content={"error": "VALIDATION_ERROR", "message": message},
    )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    return JSONResponse(
        status_code=500,
        content={"error": "INTERNAL_SERVER_ERROR", "message": "An unexpected error occurred."},
    )


app.include_router(sos.router, prefix=API_PREFIX)


@app.get("/", tags=["Health"])
def root():
    return {"status": "ok", "service": APP_TITLE, "version": APP_VERSION}

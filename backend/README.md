# ResQMesh AI — Backend

FastAPI backend implementing the frozen `resqmesh-openapi.yaml` contract
exactly. SQLite database, SQLAlchemy ORM, Pydantic v2 validation.

## Project structure

```
app/
  main.py         FastAPI app, startup table creation, error handlers
  config.py       Constants (DB path, API prefix) — nothing hardcoded elsewhere
  database.py     SQLAlchemy engine / session / Base
  enums.py        InjuryType, EmergencyLevel, PriorityLevel, SosStatus
  models.py       SosRequest ORM model
  schemas.py      Pydantic v2 request/response schemas
  crud.py         Database operations
  priority.py     Priority engine (computes priority_score / priority_level)
  routers/
    sos.py        The 5 contract endpoints
requirements.txt
README.md
```

## Run it

```bash
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate
pip install -r requirements.txt
uvicorn app.main:app --reload
```

The server starts at `http://127.0.0.1:8000`. `resqmesh.db` (SQLite) is
created automatically on first startup — no manual migration step.

- Swagger UI: http://127.0.0.1:8000/docs
- OpenAPI JSON: http://127.0.0.1:8000/openapi.json

## Endpoints (frozen — do not add/remove/rename)

| Method | Path                  | Purpose                  |
|--------|-----------------------|---------------------------|
| POST   | /api/sos              | Create an SOS request     |
| GET    | /api/sos              | List SOS requests (filter by `status`, `emergency_level`; `sort=newest\|oldest`) |
| GET    | /api/sos/{uuid}       | Get one SOS request       |
| PUT    | /api/sos/{uuid}/status| Update status only        |
| DELETE | /api/sos/{uuid}       | Delete an SOS request     |

## Enums (frozen)

- `injury_type`: `Critical`, `Serious`, `Minor`, `Pregnant`, `Child`
- `emergency_level`: `LOW`, `MEDIUM`, `HIGH`
- `status`: `PENDING`, `RECEIVED`, `ASSIGNED`, `RESCUED`
- `priority_level`: `LOW`, `MEDIUM`, `HIGH` (server-computed, read-only)

## Priority engine

`priority_score` (0–100) is computed server-side on create from:
injury-type severity weight + emergency-level weight + victim-count
(capped) + a low-battery urgency bonus. `priority_level` is thresholded
from that score. See `app/priority.py` for exact weights — tune there if
the scoring logic ever needs to change; the API shape stays the same.

## Verified before delivery

- Swagger UI and `/openapi.json` both load (200 OK)
- `resqmesh.db` is created automatically on startup
- Full CRUD cycle tested: create (x2, checked HIGH and LOW scoring paths),
  list, get-by-id, filter by status, update status, delete, get-after-delete
- Validation confirmed: invalid enum values and out-of-range fields return
  `400` with the contract's `{"error", "message"}` shape (not FastAPI's
  default 422)
- 404 confirmed for unknown uuid on GET/PUT/DELETE
- `updated_at` changes on status update; `created_at` stays fixed

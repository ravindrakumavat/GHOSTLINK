"""
Central configuration for the ResQMesh AI backend.
All environment-specific / constant values live here so nothing is
hardcoded elsewhere in the codebase.
"""

import os

# Directory of this file -> project root is one level up (app/ -> project root)
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# SQLite database file, created automatically on first run in the project root.
DATABASE_FILE = os.path.join(BASE_DIR, "resqmesh.db")
DATABASE_URL = f"sqlite:///{DATABASE_FILE}"

# API prefix, matches the OpenAPI contract's server base path (/api)
API_PREFIX = "/api"

# Application metadata (used in FastAPI/Swagger docs)
APP_TITLE = "ResQMesh AI - SOS API"
APP_VERSION = "1.0.0"
APP_DESCRIPTION = (
    "Backend service for the ResQMesh AI disaster/emergency SOS system. "
    "Implements the frozen OpenAPI contract exactly."
)

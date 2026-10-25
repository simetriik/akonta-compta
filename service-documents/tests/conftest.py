import os

import pytest
from fastapi.testclient import TestClient

os.environ.setdefault("AKONTA_SERVICE_KEY", "cle-de-test")

from app.main import app  # noqa: E402


@pytest.fixture
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture
def auth() -> dict:
    return {"X-Akonta-Service-Key": "cle-de-test"}


@pytest.fixture
def header() -> dict:
    return {
        "cabinet_name": "ABC Expertise Comptable",
        "entity_name": "SARL Démo",
        "entity_tax_id": "3201900000001",
        "fiscal_year_label": "2026",
        "period_from": "2026-01-01",
        "period_to": "2026-12-31",
        "title": "Balance générale",
        "generated_by": "Assistant A",
    }

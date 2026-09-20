import sys
from pathlib import Path

BACKEND_ROOT = Path(__file__).resolve().parents[1]
if str(BACKEND_ROOT) not in sys.path:
    sys.path.insert(0, str(BACKEND_ROOT))

import pytest
from fastapi.testclient import TestClient

from app.main import app
from app.services.store import InMemoryStore, get_store


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def fresh_store():
    """A clean, unseeded InMemoryStore for isolated unit tests."""
    return InMemoryStore(seed=False)


@pytest.fixture(autouse=True)
def _reset_store_cache():
    get_store.cache_clear()
    yield
    get_store.cache_clear()

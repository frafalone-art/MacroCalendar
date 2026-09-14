from datetime import date, timedelta

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

import main
from models import Base, MacroEvent

# DB SQLite in-memory dedicato ai test, separato da quello vero
TEST_DATABASE_URL = "sqlite:///:memory:"
engine = create_engine(
    TEST_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(autouse=True)
def setup_db(monkeypatch):
    Base.metadata.create_all(bind=engine)
    monkeypatch.setattr(main, "SessionLocal", TestingSessionLocal)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def client():
    main.app.config["TESTING"] = True
    with main.app.test_client() as c:
        yield c


def test_upcoming_events_empty(client):
    response = client.get("/events/upcoming")
    assert response.status_code == 200
    assert response.get_json() == []


def test_upcoming_events_returns_future_event(client):
    db = TestingSessionLocal()
    event = MacroEvent(
        name="ECB Press Conference",
        importance="high",
        currencies="EUR",
        date=date.today() + timedelta(days=1),
    )
    db.add(event)
    db.commit()
    db.close()

    response = client.get("/events/upcoming")
    data = response.get_json()
    assert len(data) == 1
    assert data[0]["name"] == "ECB Press Conference"
    assert data[0]["importance"] == "high"


def test_upcoming_events_excludes_past_event(client):
    db = TestingSessionLocal()
    event = MacroEvent(
        name="Old Event",
        importance="low",
        currencies="USD",
        date=date.today() - timedelta(days=1),
    )
    db.add(event)
    db.commit()
    db.close()

    response = client.get("/events/upcoming")
    assert response.get_json() == []

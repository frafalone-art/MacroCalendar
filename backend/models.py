from sqlalchemy import Column, Integer, String, Date, Time, Boolean, create_engine
from sqlalchemy.orm import declarative_base, sessionmaker

DATABASE_URL = "sqlite:///./macro_calendar.db"

engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


class MacroEvent(Base):
    __tablename__ = "macro_events"

    id = Column(Integer, primary_key=True, autoincrement=True)
    name = Column(String, nullable=False)
    importance = Column(String, nullable=False)  # high | medium | low | very_low
    currencies = Column(String, nullable=False)  # es. "EUR,USD" (comma-separated)
    date = Column(Date, nullable=False)
    time = Column(Time, nullable=True)  # nullable: alcuni speech non hanno orario fisso
    notified = Column(Boolean, default=False, nullable=False)

    def __repr__(self):
        return f"<MacroEvent {self.name} ({self.importance}) {self.date} {self.time}>"


def init_db():
    Base.metadata.create_all(bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

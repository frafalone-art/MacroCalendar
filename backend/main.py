from datetime import date

from flask import Flask, jsonify

from models import MacroEvent, init_db, SessionLocal

app = Flask(__name__)

with app.app_context():
    init_db()


@app.route("/events/upcoming")
def get_upcoming_events():
    db = SessionLocal()
    try:
        today = date.today()
        events = (
            db.query(MacroEvent)
            .filter(MacroEvent.date >= today)
            .order_by(MacroEvent.date, MacroEvent.time)
            .all()
        )
        return jsonify([
            {
                "id": e.id,
                "name": e.name,
                "importance": e.importance,
                "currencies": e.currencies.split(","),
                "date": e.date.isoformat(),
                "time": e.time.isoformat() if e.time else None,
                "notified": e.notified,
            }
            for e in events
        ])
    finally:
        db.close()


if __name__ == "__main__":
    app.run(debug=True)
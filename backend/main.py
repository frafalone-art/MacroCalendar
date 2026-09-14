from datetime import date
import os

from flask import Flask, jsonify, request

from models import MacroEvent, init_db, SessionLocal
import scraper

app = Flask(__name__)

# Chiave segreta per proteggere l'endpoint di trigger dello scraper.
# Impostala come variabile d'ambiente (o cambiala qui).
SCRAPER_SECRET = os.environ.get("SCRAPER_SECRET", "your-secret-key")

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


@app.route("/run-scraper")
def run_scraper():
    if request.args.get("key") != SCRAPER_SECRET:
        return jsonify({"error": "unauthorized"}), 401

    lines = scraper.fetch_page_text()
    all_events = scraper.parse_events(lines)
    filtered = scraper.filter_relevant(all_events)
    saved = scraper.save_events_to_db(filtered)

    return jsonify({"raw_events": len(all_events), "relevant_events": len(filtered), "saved": saved})


if __name__ == "__main__":
    app.run(debug=True)

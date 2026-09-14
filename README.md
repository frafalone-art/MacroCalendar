# 📊 macro-calendar

An Android app (Flutter) + Python backend that scrapes forex macroeconomic events (ECB, FOMC) and sends push notifications and calendar reminders.

![Flutter](https://img.shields.io/badge/Flutter-02569B?logo=flutter&logoColor=white)
![Python](https://img.shields.io/badge/Python-3776AB?logo=python&logoColor=white)
![Flask](https://img.shields.io/badge/Flask-000000?logo=flask&logoColor=white)
![SQLite](https://img.shields.io/badge/SQLite-07405E?logo=sqlite&logoColor=white)
![License](https://img.shields.io/badge/license-AGPL--3.0-blue)

## Why I built this

I kept missing high-impact macro events (ECB/FOMC press conferences, speeches, key data releases) while trading, because checking a calendar site manually every day isn't reliable — you forget, or you check too late. I wanted something that tracks the events for me and reminds me automatically, on my phone, without having to pay for a paid calendar/alert service.

There was no free API for this kind of forex/macro calendar data (Forex Factory doesn't offer one, and their ToS discourage scraping), so instead I built the pipeline around the ECB's own public weekly calendar page, which is official data with no scraping restrictions.

## 📦 What's inside

| Part | What it does |
|---|---|
| 🐍 `backend/` | Flask API + scraper that pulls events from the ECB weekly calendar, filters by keyword, and stores them in SQLite |
| 📱 `frontend/` | Flutter app showing upcoming events, with toggles for notifications and calendar access |

## ⚙️ How it works

1. `scraper.py` fetches the ECB weekly calendar page and parses events (name, date, time) — no official API exists, so this is plain HTML parsing with BeautifulSoup
2. Events matching a keyword list (`press conference`, `inflation`, `unemployment`, etc.) are kept, everything else is discarded
3. Relevant events are saved to a SQLite database, deduplicated by name + date so re-running the scraper never creates duplicates
4. An external cron service ([cron-job.org](https://cron-job.org)) calls `/run-scraper` once a day to keep the database fresh — PythonAnywhere's free tier doesn't offer scheduled tasks anymore, so this was the free workaround
5. The Flutter app fetches `/events/upcoming` and displays what's coming next

## 🖥️ Backend setup

```
cd backend
python -m venv venv
venv\Scripts\activate        # Windows
pip install -r requirements.txt
python scraper.py            # first manual run, populates the DB
python main.py                # runs locally on http://127.0.0.1:5000
```

Deployed on [PythonAnywhere](https://www.pythonanywhere.com) (free tier) — see `wsgi_pythonanywhere.py` for the WSGI entry point (edit the username path before deploying your own copy). The backend started as FastAPI, but PythonAnywhere's free tier only supports WSGI reliably, so it was rewritten in Flask.

## 🔑 Scraper trigger endpoint

`/run-scraper?key=YOUR_SECRET` re-runs the scraper on demand. Set your own secret via the `SCRAPER_SECRET` environment variable — don't leave the default in production.

## 📱 Frontend setup

```
cd frontend
flutter pub get
flutter run
```

Update `baseUrl` in `lib/main.dart` to point to your own backend deployment.

## 🧪 Tests

```
cd backend
pytest test_main.py -v
```

## 🖥️ Requirements

- Python 3.11+
- Flutter SDK
- Android device/emulator (API 24+)

## 📁 Project structure

```
macro-calendar/
├── backend/
│   ├── main.py
│   ├── models.py
│   ├── scraper.py
│   ├── test_main.py
│   ├── requirements.txt
│   └── wsgi_pythonanywhere.py
├── frontend/
│   └── (Flutter project)
├── .gitignore
└── LICENSE
```

## 👨‍💻 Author

Francesco Falone — solo developer building and deploying full-stack projects (Flask, Flutter, SQLite) on self-managed servers.

## 📄 License

Licensed under AGPL-3.0 — modifications must remain open source, even when run as a network service.

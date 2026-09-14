import re
from datetime import datetime

import requests
from bs4 import BeautifulSoup

ECB_URL = "https://www.ecb.europa.eu/press/calendars/weekly/html/index.en.html"

# Pattern per riconoscere una riga data tipo "Thursday, 10 September 2026"
DATE_PATTERN = re.compile(
    r"^(Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday),\s+"
    r"(\d{1,2})\s+(\w+)\s+(\d{4})$"
)

MONTHS = {
    "January": 1, "February": 2, "March": 3, "April": 4, "May": 5, "June": 6,
    "July": 7, "August": 8, "September": 9, "October": 10, "November": 11, "December": 12,
}

# Keyword per filtrare solo gli eventi rilevanti (case-insensitive).
# Aggiungi/rimuovi liberamente in base a cosa ti interessa monitorare.
RELEVANT_KEYWORDS = [
    "press conference",
    "monetary policy",
    "interest rate",
    "inflation",
    "unemployment",
    "employment",
    "gdp",
    "wage",
]


def is_relevant(event_name: str) -> bool:
    name_lower = event_name.lower()
    return any(keyword in name_lower for keyword in RELEVANT_KEYWORDS)


def fetch_page_text() -> str:
    resp = requests.get(ECB_URL, headers={"User-Agent": "Mozilla/5.0"}, timeout=15)
    resp.raise_for_status()
    soup = BeautifulSoup(resp.text, "html.parser")
    # prendiamo solo il testo, riga per riga, pulito
    text = soup.get_text(separator="\n")
    lines = [line.strip() for line in text.split("\n")]
    return [line for line in lines if line]  # rimuove righe vuote


def parse_events(lines: list[str]) -> list[dict]:
    events = []
    current_date = None
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]

        date_match = DATE_PATTERN.match(line)
        if date_match:
            current_date = datetime(
                int(date_match.group(4)),
                MONTHS[date_match.group(3)],
                int(date_match.group(2)),
            ).date()
            i += 1
            continue

        if line == "Event:":
            name = lines[i + 1] if i + 1 < n else ""
            time_raw = None
            j = i + 2
            if j < n and lines[j] == "Time:" and j + 1 < n:
                time_raw = lines[j + 1]
                i = j + 2
            else:
                i = j

            events.append({"date": current_date, "name": name, "time_raw": time_raw})
            continue

        i += 1

    return events


def filter_relevant(events: list[dict]) -> list[dict]:
    return [e for e in events if is_relevant(e["name"])]


if __name__ == "__main__":
    lines = fetch_page_text()
    print(f"[DEBUG] Righe scaricate dalla pagina: {len(lines)}")

    with open("debug_lines.txt", "w", encoding="utf-8") as f:
        for i, line in enumerate(lines):
            f.write(f"{i}: {line}\n")
    print("[DEBUG] Righe salvate in debug_lines.txt, apri il file e mandami un pezzo (es. le righe attorno a 'Nagel' o 'ECB')")

    all_events = parse_events(lines)
    print(f"[DEBUG] Eventi grezzi trovati (prima del filtro keyword): {len(all_events)}")
    for e in all_events:
        print("  RAW:", e["name"])

    filtered = filter_relevant(all_events)
    print(f"\n[DEBUG] Eventi dopo il filtro keyword: {len(filtered)}")
    for e in filtered:
        print(e)
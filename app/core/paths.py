import os

BASE = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DB_PATH = os.path.join(BASE, "data", "forgetmenot.db")
FACES_DIR = os.path.join(BASE, "faces")
AUDIO_DIR = os.path.join(BASE, "audio")
LOGS_DIR = os.path.join(BASE, "logs")
MOBILE_DIR = os.path.join(BASE, "mobile")
SETTINGS_FILE = os.path.join(BASE, "data", "settings.json")


def ensure_dirs() -> None:
    for d in [FACES_DIR, AUDIO_DIR, LOGS_DIR, os.path.join(BASE, "data"), MOBILE_DIR]:
        os.makedirs(d, exist_ok=True)


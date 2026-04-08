import sqlite3

from .paths import DB_PATH


def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn


def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute(
        """CREATE TABLE IF NOT EXISTS patients (
        patient_id   TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        age          INTEGER,
        relationship TEXT,
        photo_path   TEXT,
        created_at   TEXT
    )"""
    )

    c.execute(
        """CREATE TABLE IF NOT EXISTS reminders (
        reminder_id    TEXT PRIMARY KEY,
        patient_id     TEXT,
        title          TEXT NOT NULL,
        reminder_type  TEXT,
        scheduled_time TEXT,
        repeat_option  TEXT,
        voice_message  TEXT,
        status         TEXT DEFAULT 'pending',
        created_at     TEXT,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )"""
    )

    c.execute(
        """CREATE TABLE IF NOT EXISTS visitors (
        visitor_id   TEXT PRIMARY KEY,
        patient_id   TEXT,
        name         TEXT NOT NULL,
        relationship TEXT,
        created_at   TEXT,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )"""
    )

    c.execute(
        """CREATE TABLE IF NOT EXISTS visitor_photos (
        photo_id   TEXT PRIMARY KEY,
        visitor_id TEXT,
        photo_path TEXT,
        FOREIGN KEY(visitor_id) REFERENCES visitors(visitor_id)
    )"""
    )

    c.execute(
        """CREATE TABLE IF NOT EXISTS activity_logs (
        log_id       TEXT PRIMARY KEY,
        patient_id   TEXT,
        event_type   TEXT,
        event_detail TEXT,
        result       TEXT,
        timestamp    TEXT,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )"""
    )

    conn.commit()
    conn.close()


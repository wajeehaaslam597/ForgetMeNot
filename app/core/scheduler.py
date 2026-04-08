from datetime import datetime, timedelta

from apscheduler.schedulers.background import BackgroundScheduler

from .db import get_db
from .helpers import log_event

scheduler = BackgroundScheduler()


def check_reminders():
    conn = get_db()
    now = datetime.now()
    rows = conn.execute("SELECT * FROM reminders WHERE status='pending'").fetchall()
    for r in rows:
        try:
            t = datetime.fromisoformat(r["scheduled_time"])
            if t <= now:
                log_event(
                    conn,
                    r["patient_id"],
                    "reminder_triggered",
                    f"Reminder: {r['title']} | msg: {r['voice_message']}",
                    "triggered",
                )
                if r["repeat_option"] == "one-time":
                    conn.execute(
                        "UPDATE reminders SET status='completed' WHERE reminder_id=?",
                        (r["reminder_id"],),
                    )
                elif r["repeat_option"] == "daily":
                    next_t = (t + timedelta(days=1)).isoformat()
                    conn.execute(
                        "UPDATE reminders SET scheduled_time=? WHERE reminder_id=?",
                        (next_t, r["reminder_id"]),
                    )
                elif r["repeat_option"] == "weekly":
                    next_t = (t + timedelta(weeks=1)).isoformat()
                    conn.execute(
                        "UPDATE reminders SET scheduled_time=? WHERE reminder_id=?",
                        (next_t, r["reminder_id"]),
                    )
        except Exception:
            pass
    conn.commit()
    conn.close()


def start_scheduler():
    scheduler.add_job(check_reminders, "interval", seconds=30)
    scheduler.start()


def stop_scheduler():
    scheduler.shutdown()


import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException

from ..core.db import get_db
from ..core.helpers import log_event, row_to_dict
from ..schemas import ReminderCreate, ReminderStatusUpdate

router = APIRouter(tags=["Reminders"])


@router.post("/reminders")
def create_reminder(reminder: ReminderCreate):
    rid = str(uuid.uuid4())
    msg = reminder.voice_message or f"Reminder: {reminder.title}"
    conn = get_db()
    conn.execute(
        "INSERT INTO reminders VALUES (?,?,?,?,?,?,?,?,?)",
        (
            rid,
            reminder.patient_id,
            reminder.title,
            reminder.reminder_type,
            reminder.scheduled_time,
            reminder.repeat_option,
            msg,
            "pending",
            datetime.now().isoformat(),
        ),
    )
    log_event(conn, reminder.patient_id, "reminder_created", f"{reminder.title} at {reminder.scheduled_time}", "ok")
    conn.commit()
    conn.close()
    return {"reminder_id": rid, "message": "Reminder scheduled", "voice_message": msg}


@router.get("/reminders/{patient_id}")
def get_reminders(patient_id: str, date: Optional[str] = None):
    conn = get_db()
    if date:
        rows = conn.execute(
            "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
            (patient_id, f"{date}%"),
        ).fetchall()
    else:
        rows = conn.execute("SELECT * FROM reminders WHERE patient_id=?", (patient_id,)).fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]


@router.get("/reminders/{patient_id}/today")
def get_todays_reminders(patient_id: str):
    today = datetime.now().strftime("%Y-%m-%d")
    conn = get_db()
    rows = conn.execute(
        "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
        (patient_id, f"{today}%"),
    ).fetchall()
    conn.close()
    reminders = [row_to_dict(r) for r in rows]
    return {
        "date": today,
        "total": len(reminders),
        "completed": sum(1 for r in reminders if r["status"] == "completed"),
        "missed": sum(1 for r in reminders if r["status"] == "missed"),
        "pending": sum(1 for r in reminders if r["status"] == "pending"),
        "reminders": reminders,
    }


@router.put("/reminders/{reminder_id}/status")
def update_reminder_status(reminder_id: str, update: ReminderStatusUpdate):
    conn = get_db()
    row = conn.execute("SELECT * FROM reminders WHERE reminder_id=?", (reminder_id,)).fetchone()
    if not row:
        raise HTTPException(404, "Reminder not found")
    conn.execute("UPDATE reminders SET status=? WHERE reminder_id=?", (update.status, reminder_id))
    log_event(conn, row["patient_id"], "reminder_status", f"Reminder {row['title']}", update.status)
    conn.commit()
    conn.close()
    return {"message": f"Reminder marked as {update.status}"}


@router.delete("/reminders/{reminder_id}")
def delete_reminder(reminder_id: str):
    conn = get_db()
    conn.execute("DELETE FROM reminders WHERE reminder_id=?", (reminder_id,))
    conn.commit()
    conn.close()
    return {"message": "Reminder deleted"}


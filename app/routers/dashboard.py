from datetime import datetime

from fastapi import APIRouter, HTTPException

from ..core.db import get_db
from ..core.helpers import row_to_dict

router = APIRouter(tags=["Caregiver Dashboard"])


@router.get("/dashboard/{patient_id}")
def get_dashboard(patient_id: str):
    conn = get_db()
    patient = conn.execute("SELECT * FROM patients WHERE patient_id=?", (patient_id,)).fetchone()
    if not patient:
        raise HTTPException(404, "Patient not found")

    today = datetime.now().strftime("%Y-%m-%d")
    rem_rows = conn.execute(
        "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
        (patient_id, f"{today}%"),
    ).fetchall()
    recent_logs = conn.execute(
        "SELECT * FROM activity_logs WHERE patient_id=? ORDER BY timestamp DESC LIMIT 10",
        (patient_id,),
    ).fetchall()
    visitor_count = conn.execute("SELECT COUNT(*) FROM visitors WHERE patient_id=?", (patient_id,)).fetchone()[0]
    reminders = [row_to_dict(r) for r in rem_rows]
    conn.close()

    return {
        "patient": row_to_dict(patient),
        "today_reminders": {
            "total": len(reminders),
            "completed": sum(1 for r in reminders if r["status"] == "completed"),
            "missed": sum(1 for r in reminders if r["status"] == "missed"),
            "pending": sum(1 for r in reminders if r["status"] == "pending"),
            "items": reminders,
        },
        "visitor_count": visitor_count,
        "recent_logs": [row_to_dict(l) for l in recent_logs],
    }


@router.get("/dashboard/all/patients")
def get_all_patients_summary():
    conn = get_db()
    patients = conn.execute("SELECT * FROM patients").fetchall()
    today = datetime.now().strftime("%Y-%m-%d")
    result = []
    for p in patients:
        pid = p["patient_id"]
        pending = conn.execute(
            "SELECT COUNT(*) FROM reminders WHERE patient_id=? AND status='pending' AND scheduled_time LIKE ?",
            (pid, f"{today}%"),
        ).fetchone()[0]
        result.append({**row_to_dict(p), "pending_reminders_today": pending})
    conn.close()
    return result


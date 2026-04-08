from datetime import datetime
from typing import Optional

from fastapi import APIRouter

from ..core.db import get_db
from ..core.helpers import row_to_dict

router = APIRouter(tags=["Activity Logs"])


@router.get("/logs/{patient_id}")
def get_logs(patient_id: str, date: Optional[str] = None, event_type: Optional[str] = None):
    conn = get_db()
    query = "SELECT * FROM activity_logs WHERE patient_id=?"
    params = [patient_id]
    if date:
        query += " AND timestamp LIKE ?"
        params.append(f"{date}%")
    if event_type:
        query += " AND event_type=?"
        params.append(event_type)
    query += " ORDER BY timestamp DESC"
    rows = conn.execute(query, params).fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]


@router.get("/logs/{patient_id}/summary")
def get_log_summary(patient_id: str):
    conn = get_db()
    today = datetime.now().strftime("%Y-%m-%d")
    total_logs = conn.execute("SELECT COUNT(*) FROM activity_logs WHERE patient_id=?", (patient_id,)).fetchone()[0]
    today_logs = conn.execute(
        "SELECT COUNT(*) FROM activity_logs WHERE patient_id=? AND timestamp LIKE ?",
        (patient_id, f"{today}%"),
    ).fetchone()[0]
    face_ok = conn.execute(
        "SELECT COUNT(*) FROM activity_logs WHERE patient_id=? AND event_type='face_recognition' AND result='success'",
        (patient_id,),
    ).fetchone()[0]
    rem_done = conn.execute("SELECT COUNT(*) FROM reminders WHERE patient_id=? AND status='completed'", (patient_id,)).fetchone()[0]
    rem_missed = conn.execute("SELECT COUNT(*) FROM reminders WHERE patient_id=? AND status='missed'", (patient_id,)).fetchone()[0]
    conn.close()
    return {
        "patient_id": patient_id,
        "total_logs": total_logs,
        "today_logs": today_logs,
        "face_recognitions_success": face_ok,
        "reminders_completed": rem_done,
        "reminders_missed": rem_missed,
    }


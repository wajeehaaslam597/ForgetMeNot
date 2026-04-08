import uuid
from datetime import datetime


def log_event(conn, patient_id, event_type, detail, result):
    conn.execute(
        "INSERT INTO activity_logs VALUES (?,?,?,?,?,?)",
        (str(uuid.uuid4()), patient_id, event_type, detail, result, datetime.now().isoformat()),
    )


def row_to_dict(row):
    return dict(row) if row else None


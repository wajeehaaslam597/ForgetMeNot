import os
import shutil
import uuid
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, UploadFile

from ..core.db import get_db
from ..core.helpers import row_to_dict
from ..core.paths import FACES_DIR
from ..schemas import PatientCreate

router = APIRouter(tags=["Patient"])


@router.post("/patients")
async def create_patient(patient: PatientCreate):
    pid = str(uuid.uuid4())
    conn = get_db()
    conn.execute(
        "INSERT INTO patients VALUES (?,?,?,?,?,?)",
        (pid, patient.name, patient.age, patient.relationship, None, datetime.now().isoformat()),
    )
    conn.commit()
    conn.close()
    return {"patient_id": pid, "name": patient.name, "message": "Patient created"}


@router.get("/patients")
def list_patients():
    conn = get_db()
    rows = conn.execute("SELECT * FROM patients").fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]


@router.get("/patients/{patient_id}")
def get_patient(patient_id: str):
    conn = get_db()
    row = conn.execute("SELECT * FROM patients WHERE patient_id=?", (patient_id,)).fetchone()
    conn.close()
    if not row:
        raise HTTPException(404, "Patient not found")
    return row_to_dict(row)


@router.put("/patients/{patient_id}")
async def update_patient(patient_id: str, patient: PatientCreate):
    conn = get_db()
    conn.execute(
        "UPDATE patients SET name=?, age=?, relationship=? WHERE patient_id=?",
        (patient.name, patient.age, patient.relationship, patient_id),
    )
    conn.commit()
    conn.close()
    return {"message": "Patient updated"}


@router.post("/patients/{patient_id}/photo")
async def upload_patient_photo(patient_id: str, file: UploadFile = File(...)):
    ext = file.filename.split(".")[-1]
    path = os.path.join(FACES_DIR, f"patient_{patient_id}.{ext}")
    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    conn = get_db()
    conn.execute("UPDATE patients SET photo_path=? WHERE patient_id=?", (path, patient_id))
    conn.commit()
    conn.close()
    return {"message": "Photo uploaded", "path": path}


@router.delete("/patients/{patient_id}")
def delete_patient(patient_id: str):
    conn = get_db()
    conn.execute("DELETE FROM patients WHERE patient_id=?", (patient_id,))
    conn.commit()
    conn.close()
    return {"message": "Patient deleted"}


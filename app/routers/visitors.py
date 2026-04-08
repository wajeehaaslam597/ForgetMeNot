import json
import os
import shutil
import uuid
from datetime import datetime

from fastapi import APIRouter, File, HTTPException, UploadFile

from ..core.db import get_db
from ..core.helpers import log_event, row_to_dict
from ..core.paths import FACES_DIR
from ..schemas import VisitorCreate

router = APIRouter(tags=["Face Recognition"])


@router.post("/visitors")
def add_visitor(visitor: VisitorCreate):
    vid = str(uuid.uuid4())
    conn = get_db()
    conn.execute(
        "INSERT INTO visitors VALUES (?,?,?,?,?)",
        (vid, visitor.patient_id, visitor.name, visitor.relationship, datetime.now().isoformat()),
    )
    log_event(conn, visitor.patient_id, "visitor_added", f"{visitor.name} ({visitor.relationship})", "ok")
    conn.commit()
    conn.close()
    return {"visitor_id": vid, "message": "Visitor registered"}


@router.post("/visitors/{visitor_id}/photos")
async def upload_visitor_photo(visitor_id: str, file: UploadFile = File(...)):
    conn = get_db()
    visitor = conn.execute("SELECT * FROM visitors WHERE visitor_id=?", (visitor_id,)).fetchone()
    if not visitor:
        raise HTTPException(404, "Visitor not found")

    pid = str(uuid.uuid4())
    ext = file.filename.split(".")[-1].lower()
    path = os.path.join(FACES_DIR, f"visitor_{visitor_id}_{pid}.{ext}")
    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    embedding_path = None
    try:
        import cv2
        from deepface import DeepFace

        img = cv2.imread(path)
        if img is not None:
            result = DeepFace.represent(img_path=path, model_name="Facenet", enforce_detection=False)
            embedding = result[0]["embedding"]
            emb_file = path.replace(f".{ext}", "_emb.json")
            with open(emb_file, "w") as ef:
                json.dump({"visitor_id": visitor_id, "embedding": embedding}, ef)
            embedding_path = emb_file
    except Exception:
        embedding_path = None

    conn.execute("INSERT INTO visitor_photos VALUES (?,?,?)", (pid, visitor_id, path))
    conn.commit()
    conn.close()
    return {
        "photo_id": pid,
        "photo_path": path,
        "embedding_generated": embedding_path is not None,
        "message": "Photo uploaded",
    }


@router.get("/visitors/{patient_id}")
def get_visitors(patient_id: str):
    conn = get_db()
    visitors = conn.execute("SELECT * FROM visitors WHERE patient_id=?", (patient_id,)).fetchall()
    result = []
    for v in visitors:
        photos = conn.execute("SELECT * FROM visitor_photos WHERE visitor_id=?", (v["visitor_id"],)).fetchall()
        vd = row_to_dict(v)
        vd["photos"] = [row_to_dict(p) for p in photos]
        result.append(vd)
    conn.close()
    return result


@router.post("/face/recognize/{patient_id}")
async def recognize_face(patient_id: str, file: UploadFile = File(...)):
    tmp_path = os.path.join(FACES_DIR, f"tmp_frame_{uuid.uuid4()}.jpg")
    with open(tmp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    conn = get_db()
    result_data = {
        "recognized": False,
        "visitor_name": None,
        "relationship": None,
        "confidence": 0.0,
        "message": "Could not recognize this person",
    }

    try:
        import numpy as np
        from deepface import DeepFace

        probe_result = DeepFace.represent(img_path=tmp_path, model_name="Facenet", enforce_detection=False)
        probe_emb = np.array(probe_result[0]["embedding"])

        visitors = conn.execute("SELECT * FROM visitors WHERE patient_id=?", (patient_id,)).fetchall()
        best_score = -1
        best_visitor = None

        for v in visitors:
            emb_files = [
                fn
                for fn in os.listdir(FACES_DIR)
                if fn.startswith(f"visitor_{v['visitor_id']}") and fn.endswith("_emb.json")
            ]
            for ef in emb_files:
                try:
                    with open(os.path.join(FACES_DIR, ef)) as jf:
                        stored = json.load(jf)
                    stored_emb = np.array(stored["embedding"])
                    cos_sim = float(
                        np.dot(probe_emb, stored_emb)
                        / (np.linalg.norm(probe_emb) * np.linalg.norm(stored_emb) + 1e-8)
                    )
                    if cos_sim > best_score:
                        best_score = cos_sim
                        best_visitor = v
                except Exception:
                    continue

        threshold = 0.70
        if best_visitor and best_score >= threshold:
            result_data = {
                "recognized": True,
                "visitor_name": best_visitor["name"],
                "relationship": best_visitor["relationship"],
                "confidence": round(best_score, 4),
                "message": f"Hello! This is {best_visitor['name']}, your {best_visitor['relationship']}.",
            }
            log_event(conn, patient_id, "face_recognition", f"Recognized: {best_visitor['name']}", "success")
        else:
            log_event(conn, patient_id, "face_recognition", "Unknown face detected", "no_match")
    except Exception as e:
        result_data["message"] = f"Recognition error: {str(e)}"
        log_event(conn, patient_id, "face_recognition", str(e), "error")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    conn.commit()
    conn.close()
    return result_data


@router.delete("/visitors/{visitor_id}")
def delete_visitor(visitor_id: str):
    conn = get_db()
    conn.execute("DELETE FROM visitor_photos WHERE visitor_id=?", (visitor_id,))
    conn.execute("DELETE FROM visitors WHERE visitor_id=?", (visitor_id,))
    conn.commit()
    conn.close()
    for fn in os.listdir(FACES_DIR):
        if fn.startswith(f"visitor_{visitor_id}"):
            try:
                os.remove(os.path.join(FACES_DIR, fn))
            except Exception:
                pass
    return {"message": "Visitor deleted"}


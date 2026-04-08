"""
ForgetMeNot - Alzheimer's Assistant Backend
MVP Backend - FastAPI
Covers: Reminder System, Face Recognition, Voice (TTS), Caregiver Dashboard, Activity Logs
Auth skipped for MVP as requested.
TTS: edge-tts (Microsoft Neural Voices) — no espeak/pyttsx3 needed, works on Windows natively.
"""

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, BackgroundTasks
from fastapi.responses import FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List
import json, os, uuid, shutil, base64, asyncio
from datetime import datetime, timedelta
from apscheduler.schedulers.background import BackgroundScheduler
import sqlite3
import edge_tts

# ── DB & paths ────────────────────────────────────────────────────────────────
BASE      = os.path.dirname(os.path.abspath(__file__))
DB_PATH   = os.path.join(BASE, "data", "forgetmenot.db")
FACES_DIR = os.path.join(BASE, "faces")
AUDIO_DIR = os.path.join(BASE, "audio")
LOGS_DIR  = os.path.join(BASE, "logs")
MOBILE_DIR = os.path.join(BASE, "mobile")

for d in [FACES_DIR, AUDIO_DIR, LOGS_DIR, os.path.join(BASE, "data"), MOBILE_DIR]:
    os.makedirs(d, exist_ok=True)

# ── App ───────────────────────────────────────────────────────────────────────
app = FastAPI(
    title="ForgetMeNot API",
    description="Alzheimer's Assistive App Backend - FYP COMSATS",
    version="1.0.0"
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Database ──────────────────────────────────────────────────────────────────
def get_db():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.row_factory = sqlite3.Row
    return conn

def init_db():
    conn = get_db()
    c = conn.cursor()

    c.execute("""CREATE TABLE IF NOT EXISTS patients (
        patient_id   TEXT PRIMARY KEY,
        name         TEXT NOT NULL,
        age          INTEGER,
        relationship TEXT,
        photo_path   TEXT,
        created_at   TEXT
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS reminders (
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
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS visitors (
        visitor_id   TEXT PRIMARY KEY,
        patient_id   TEXT,
        name         TEXT NOT NULL,
        relationship TEXT,
        created_at   TEXT,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS visitor_photos (
        photo_id   TEXT PRIMARY KEY,
        visitor_id TEXT,
        photo_path TEXT,
        FOREIGN KEY(visitor_id) REFERENCES visitors(visitor_id)
    )""")

    c.execute("""CREATE TABLE IF NOT EXISTS activity_logs (
        log_id       TEXT PRIMARY KEY,
        patient_id   TEXT,
        event_type   TEXT,
        event_detail TEXT,
        result       TEXT,
        timestamp    TEXT,
        FOREIGN KEY(patient_id) REFERENCES patients(patient_id)
    )""")

    conn.commit()
    conn.close()

init_db()

# ── Scheduler ─────────────────────────────────────────────────────────────────
scheduler = BackgroundScheduler()

def check_reminders():
    """Background job: fires every 30 s, checks due reminders and logs them."""
    conn = get_db()
    now  = datetime.now()
    rows = conn.execute("SELECT * FROM reminders WHERE status='pending'").fetchall()
    for r in rows:
        try:
            t = datetime.fromisoformat(r["scheduled_time"])
            if t <= now:
                log_event(
                    conn, r["patient_id"],
                    "reminder_triggered",
                    f"Reminder: {r['title']} | msg: {r['voice_message']}",
                    "triggered"
                )
                if r["repeat_option"] == "one-time":
                    conn.execute(
                        "UPDATE reminders SET status='completed' WHERE reminder_id=?",
                        (r["reminder_id"],)
                    )
                elif r["repeat_option"] == "daily":
                    next_t = (t + timedelta(days=1)).isoformat()
                    conn.execute(
                        "UPDATE reminders SET scheduled_time=? WHERE reminder_id=?",
                        (next_t, r["reminder_id"])
                    )
                elif r["repeat_option"] == "weekly":
                    next_t = (t + timedelta(weeks=1)).isoformat()
                    conn.execute(
                        "UPDATE reminders SET scheduled_time=? WHERE reminder_id=?",
                        (next_t, r["reminder_id"])
                    )
        except Exception:
            pass
    conn.commit()
    conn.close()

scheduler.add_job(check_reminders, "interval", seconds=30)
scheduler.start()

# ── Helpers ───────────────────────────────────────────────────────────────────
def log_event(conn, patient_id, event_type, detail, result):
    conn.execute(
        "INSERT INTO activity_logs VALUES (?,?,?,?,?,?)",
        (str(uuid.uuid4()), patient_id, event_type, detail, result,
         datetime.now().isoformat())
    )

def row_to_dict(row):
    return dict(row) if row else None

# ═══════════════════════════════════════════════════════════════════════════════
#  TTS ENGINE — edge-tts (Microsoft Neural Voices)
#  pip install edge-tts
#  No API key needed. No espeak. No pyttsx3. Works on Windows / Mac / Linux.
# ═══════════════════════════════════════════════════════════════════════════════

VOICE_MAP = {
    "en": "en-US-JennyNeural",   # clear, warm female voice — ideal for patients
    "ur": "ur-PK-UzmaNeural",    # Urdu female voice
}

async def _tts_async(text: str, filename_base: str, language: str = "en") -> str:
    """Async core: save edge-tts output as MP3."""
    voice = VOICE_MAP.get(language, VOICE_MAP["en"])
    path  = os.path.join(AUDIO_DIR, f"{filename_base}.mp3")
    communicate = edge_tts.Communicate(text, voice=voice)
    await communicate.save(path)
    return path

def local_tts(text: str, filename_base: str, language: str = "en") -> str:
    """
    Sync wrapper around async edge-tts.
    Safely handles both sync and async calling contexts (FastAPI endpoints).
    """
    try:
        loop = asyncio.get_event_loop()
        if loop.is_running():
            # Called from inside an async FastAPI route — run in a thread pool
            import concurrent.futures
            with concurrent.futures.ThreadPoolExecutor() as pool:
                future = pool.submit(asyncio.run, _tts_async(text, filename_base, language))
                return future.result()
        else:
            return loop.run_until_complete(_tts_async(text, filename_base, language))
    except RuntimeError:
        return asyncio.run(_tts_async(text, filename_base, language))

# ── Pydantic Models ────────────────────────────────────────────────────────────
class PatientCreate(BaseModel):
    name: str
    age: Optional[int] = None
    relationship: Optional[str] = None

class ReminderCreate(BaseModel):
    patient_id:     str
    title:          str
    reminder_type:  str               # medication | appointment | meal | custom
    scheduled_time: str               # ISO: 2025-10-10T09:00:00
    repeat_option:  str = "one-time"  # one-time | daily | weekly | custom
    voice_message:  Optional[str] = None

class ReminderStatusUpdate(BaseModel):
    status: str   # completed | missed | snoozed

class VisitorCreate(BaseModel):
    patient_id:   str
    name:         str
    relationship: str

# ── Root ──────────────────────────────────────────────────────────────────────
@app.get("/", tags=["Health"])
def root():
    return {
        "app":        "ForgetMeNot",
        "status":     "running",
        "version":    "1.0.0",
        "mobile_web": "/mobile/",
        "tts_engine": "edge-tts (Microsoft Neural Voices — en & ur)",
        "modules": [
            "Patient Management",
            "Reminder System",
            "Face Recognition",
            "Voice Assistant (TTS)",
            "Activity Logs",
            "Caregiver Dashboard",
            "Settings",
        ]
    }

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 1 — PATIENT MANAGEMENT
# ═══════════════════════════════════════════════════════════════════════════════

@app.post("/patients", tags=["Patient"])
async def create_patient(patient: PatientCreate):
    """Create a new patient profile."""
    pid  = str(uuid.uuid4())
    conn = get_db()
    conn.execute(
        "INSERT INTO patients VALUES (?,?,?,?,?,?)",
        (pid, patient.name, patient.age, patient.relationship,
         None, datetime.now().isoformat())
    )
    conn.commit()
    conn.close()
    return {"patient_id": pid, "name": patient.name, "message": "Patient created"}

@app.get("/patients", tags=["Patient"])
def list_patients():
    """List all patient profiles."""
    conn = get_db()
    rows = conn.execute("SELECT * FROM patients").fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]

@app.get("/patients/{patient_id}", tags=["Patient"])
def get_patient(patient_id: str):
    """Get a specific patient."""
    conn = get_db()
    row  = conn.execute(
        "SELECT * FROM patients WHERE patient_id=?", (patient_id,)
    ).fetchone()
    conn.close()
    if not row:
        raise HTTPException(404, "Patient not found")
    return row_to_dict(row)

@app.put("/patients/{patient_id}", tags=["Patient"])
async def update_patient(patient_id: str, patient: PatientCreate):
    """Update patient profile."""
    conn = get_db()
    conn.execute(
        "UPDATE patients SET name=?, age=?, relationship=? WHERE patient_id=?",
        (patient.name, patient.age, patient.relationship, patient_id)
    )
    conn.commit()
    conn.close()
    return {"message": "Patient updated"}

@app.post("/patients/{patient_id}/photo", tags=["Patient"])
async def upload_patient_photo(patient_id: str, file: UploadFile = File(...)):
    """Upload patient profile photo."""
    ext  = file.filename.split(".")[-1]
    path = os.path.join(FACES_DIR, f"patient_{patient_id}.{ext}")
    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)
    conn = get_db()
    conn.execute("UPDATE patients SET photo_path=? WHERE patient_id=?", (path, patient_id))
    conn.commit()
    conn.close()
    return {"message": "Photo uploaded", "path": path}

@app.delete("/patients/{patient_id}", tags=["Patient"])
def delete_patient(patient_id: str):
    conn = get_db()
    conn.execute("DELETE FROM patients WHERE patient_id=?", (patient_id,))
    conn.commit()
    conn.close()
    return {"message": "Patient deleted"}

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 2 — REMINDER SYSTEM
# ═══════════════════════════════════════════════════════════════════════════════

@app.post("/reminders", tags=["Reminders"])
def create_reminder(reminder: ReminderCreate):
    """Caregiver creates a reminder for a patient."""
    rid = str(uuid.uuid4())
    msg = reminder.voice_message or f"Reminder: {reminder.title}"
    conn = get_db()
    conn.execute(
        "INSERT INTO reminders VALUES (?,?,?,?,?,?,?,?,?)",
        (rid, reminder.patient_id, reminder.title, reminder.reminder_type,
         reminder.scheduled_time, reminder.repeat_option, msg,
         "pending", datetime.now().isoformat())
    )
    log_event(conn, reminder.patient_id, "reminder_created",
              f"{reminder.title} at {reminder.scheduled_time}", "ok")
    conn.commit()
    conn.close()
    return {"reminder_id": rid, "message": "Reminder scheduled", "voice_message": msg}

@app.get("/reminders/{patient_id}", tags=["Reminders"])
def get_reminders(patient_id: str, date: Optional[str] = None):
    """Get all reminders for a patient. Optional filter: ?date=YYYY-MM-DD"""
    conn = get_db()
    if date:
        rows = conn.execute(
            "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
            (patient_id, f"{date}%")
        ).fetchall()
    else:
        rows = conn.execute(
            "SELECT * FROM reminders WHERE patient_id=?", (patient_id,)
        ).fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]

@app.get("/reminders/{patient_id}/today", tags=["Reminders"])
def get_todays_reminders(patient_id: str):
    """Dashboard summary: today's reminders with counts."""
    today = datetime.now().strftime("%Y-%m-%d")
    conn  = get_db()
    rows  = conn.execute(
        "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
        (patient_id, f"{today}%")
    ).fetchall()
    conn.close()
    reminders = [row_to_dict(r) for r in rows]
    return {
        "date":      today,
        "total":     len(reminders),
        "completed": sum(1 for r in reminders if r["status"] == "completed"),
        "missed":    sum(1 for r in reminders if r["status"] == "missed"),
        "pending":   sum(1 for r in reminders if r["status"] == "pending"),
        "reminders": reminders,
    }

@app.put("/reminders/{reminder_id}/status", tags=["Reminders"])
def update_reminder_status(reminder_id: str, update: ReminderStatusUpdate):
    """Patient marks reminder as done / missed / snoozed."""
    conn = get_db()
    row  = conn.execute(
        "SELECT * FROM reminders WHERE reminder_id=?", (reminder_id,)
    ).fetchone()
    if not row:
        raise HTTPException(404, "Reminder not found")
    conn.execute(
        "UPDATE reminders SET status=? WHERE reminder_id=?",
        (update.status, reminder_id)
    )
    log_event(conn, row["patient_id"], "reminder_status",
              f"Reminder {row['title']}", update.status)
    conn.commit()
    conn.close()
    return {"message": f"Reminder marked as {update.status}"}

@app.delete("/reminders/{reminder_id}", tags=["Reminders"])
def delete_reminder(reminder_id: str):
    conn = get_db()
    conn.execute("DELETE FROM reminders WHERE reminder_id=?", (reminder_id,))
    conn.commit()
    conn.close()
    return {"message": "Reminder deleted"}

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 3 — VISITOR MANAGEMENT & FACE RECOGNITION
# ═══════════════════════════════════════════════════════════════════════════════

@app.post("/visitors", tags=["Face Recognition"])
def add_visitor(visitor: VisitorCreate):
    """Caregiver registers a visitor."""
    vid  = str(uuid.uuid4())
    conn = get_db()
    conn.execute(
        "INSERT INTO visitors VALUES (?,?,?,?,?)",
        (vid, visitor.patient_id, visitor.name,
         visitor.relationship, datetime.now().isoformat())
    )
    log_event(conn, visitor.patient_id, "visitor_added",
              f"{visitor.name} ({visitor.relationship})", "ok")
    conn.commit()
    conn.close()
    return {"visitor_id": vid, "message": "Visitor registered"}

@app.post("/visitors/{visitor_id}/photos", tags=["Face Recognition"])
async def upload_visitor_photo(visitor_id: str, file: UploadFile = File(...)):
    """
    Upload a photo for a visitor.
    Automatically generates a DeepFace (Facenet) embedding stored as a JSON file
    alongside the image — used during face recognition comparisons.
    """
    conn    = get_db()
    visitor = conn.execute(
        "SELECT * FROM visitors WHERE visitor_id=?", (visitor_id,)
    ).fetchone()
    if not visitor:
        raise HTTPException(404, "Visitor not found")

    pid  = str(uuid.uuid4())
    ext  = file.filename.split(".")[-1].lower()
    path = os.path.join(FACES_DIR, f"visitor_{visitor_id}_{pid}.{ext}")

    with open(path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    embedding_path = None
    try:
        import cv2
        import numpy as np
        from deepface import DeepFace

        img = cv2.imread(path)
        if img is not None:
            result    = DeepFace.represent(
                img_path=path,
                model_name="Facenet",
                enforce_detection=False
            )
            embedding = result[0]["embedding"]
            emb_file  = path.replace(f".{ext}", "_emb.json")
            with open(emb_file, "w") as ef:
                json.dump({"visitor_id": visitor_id, "embedding": embedding}, ef)
            embedding_path = emb_file
    except Exception:
        embedding_path = None   # photo saved even if embedding generation fails

    conn.execute("INSERT INTO visitor_photos VALUES (?,?,?)", (pid, visitor_id, path))
    conn.commit()
    conn.close()

    return {
        "photo_id":            pid,
        "photo_path":          path,
        "embedding_generated": embedding_path is not None,
        "message":             "Photo uploaded",
    }

@app.get("/visitors/{patient_id}", tags=["Face Recognition"])
def get_visitors(patient_id: str):
    """List all registered visitors for a patient (with their photos)."""
    conn     = get_db()
    visitors = conn.execute(
        "SELECT * FROM visitors WHERE patient_id=?", (patient_id,)
    ).fetchall()
    result = []
    for v in visitors:
        photos = conn.execute(
            "SELECT * FROM visitor_photos WHERE visitor_id=?", (v["visitor_id"],)
        ).fetchall()
        vd           = row_to_dict(v)
        vd["photos"] = [row_to_dict(p) for p in photos]
        result.append(vd)
    conn.close()
    return result

@app.post("/face/recognize/{patient_id}", tags=["Face Recognition"])
async def recognize_face(patient_id: str, file: UploadFile = File(...)):
    """
    Core Face Recognition Endpoint.
    Upload a live camera frame → compared against all stored visitor embeddings
    via cosine similarity (Facenet 128-dim vectors).
    Threshold: cosine similarity ≥ 0.70 → recognized.
    Returns name, relationship, confidence score, and a spoken announcement string.
    """
    tmp_path = os.path.join(FACES_DIR, f"tmp_frame_{uuid.uuid4()}.jpg")
    with open(tmp_path, "wb") as f:
        shutil.copyfileobj(file.file, f)

    conn        = get_db()
    result_data = {
        "recognized":   False,
        "visitor_name": None,
        "relationship": None,
        "confidence":   0.0,
        "message":      "Could not recognize this person",
    }

    try:
        import numpy as np
        from deepface import DeepFace

        probe_result = DeepFace.represent(
            img_path=tmp_path,
            model_name="Facenet",
            enforce_detection=False
        )
        probe_emb = np.array(probe_result[0]["embedding"])

        visitors     = conn.execute(
            "SELECT * FROM visitors WHERE patient_id=?", (patient_id,)
        ).fetchall()
        best_score   = -1
        best_visitor = None

        for v in visitors:
            emb_files = [
                fn for fn in os.listdir(FACES_DIR)
                if fn.startswith(f"visitor_{v['visitor_id']}") and fn.endswith("_emb.json")
            ]
            for ef in emb_files:
                try:
                    with open(os.path.join(FACES_DIR, ef)) as jf:
                        stored = json.load(jf)
                    stored_emb = np.array(stored["embedding"])
                    cos_sim    = float(
                        np.dot(probe_emb, stored_emb) /
                        (np.linalg.norm(probe_emb) * np.linalg.norm(stored_emb) + 1e-8)
                    )
                    if cos_sim > best_score:
                        best_score   = cos_sim
                        best_visitor = v
                except Exception:
                    continue

        THRESHOLD = 0.70
        if best_visitor and best_score >= THRESHOLD:
            result_data = {
                "recognized":   True,
                "visitor_name": best_visitor["name"],
                "relationship": best_visitor["relationship"],
                "confidence":   round(best_score, 4),
                "message":      (
                    f"Hello! This is {best_visitor['name']}, "
                    f"your {best_visitor['relationship']}."
                ),
            }
            log_event(conn, patient_id, "face_recognition",
                      f"Recognized: {best_visitor['name']}", "success")
        else:
            log_event(conn, patient_id, "face_recognition",
                      "Unknown face detected", "no_match")

    except Exception as e:
        result_data["message"] = f"Recognition error: {str(e)}"
        log_event(conn, patient_id, "face_recognition", str(e), "error")
    finally:
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    conn.commit()
    conn.close()
    return result_data

@app.delete("/visitors/{visitor_id}", tags=["Face Recognition"])
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

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 4 — VOICE ASSISTANT  (edge-tts — Microsoft Neural Voices)
# ═══════════════════════════════════════════════════════════════════════════════

@app.post("/voice/tts", tags=["Voice Assistant"])
def generate_tts(
    text:       str           = Form(...),
    language:   str           = Form("en"),   # "en" or "ur"
    patient_id: Optional[str] = Form(None),
):
    """
    Text-to-Speech using edge-tts (Microsoft Neural Voices).
    • English → en-US-JennyNeural
    • Urdu    → ur-PK-UzmaNeural
    Returns an MP3 file ready for playback on the patient's device.
    Requires internet connection (Microsoft Edge TTS — free, no API key needed).
    """
    try:
        filename_base = f"tts_{uuid.uuid4()}"
        path          = local_tts(text, filename_base, language)

        if patient_id:
            conn = get_db()
            log_event(conn, patient_id, "tts_generated", text[:100], language)
            conn.commit()
            conn.close()

        return FileResponse(
            path, media_type="audio/mpeg", filename=f"{filename_base}.mp3"
        )
    except Exception as e:
        raise HTTPException(500, f"TTS failed: {str(e)}")

@app.post("/voice/reminder-audio/{reminder_id}", tags=["Voice Assistant"])
def generate_reminder_audio(reminder_id: str, language: str = "en"):
    """
    Generate and return MP3 audio for a specific reminder's voice message.
    Pass ?language=ur for Urdu output.
    """
    conn = get_db()
    r    = conn.execute(
        "SELECT * FROM reminders WHERE reminder_id=?", (reminder_id,)
    ).fetchone()
    conn.close()
    if not r:
        raise HTTPException(404, "Reminder not found")

    text = r["voice_message"] or f"Reminder: {r['title']}"
    try:
        path = local_tts(text, f"reminder_{reminder_id}", language)
        return FileResponse(
            path, media_type="audio/mpeg", filename=f"reminder_{reminder_id}.mp3"
        )
    except Exception as e:
        raise HTTPException(500, f"TTS failed: {str(e)}")

@app.post("/voice/recognize-response", tags=["Voice Assistant"])
def voice_command_response(
    command:    str = Form(...),
    patient_id: str = Form(...),
    language:   str = Form("en"),
):
    """
    Process a patient voice command → text response + MP3 audio URL.

    Supported intents (case-insensitive):
      • "what are my reminders" / "reminders" / "schedule" / "medicine" / "appointment"
      • "call my caregiver"
      • "who are you" / "help" / "what are you"
      • "what time is it" / "time"
      • "what is today's date" / "date" / "today"
    """
    command_lower = command.lower().strip()
    conn          = get_db()

    # ── Intent matching ──────────────────────────────────────────────────────
    if any(w in command_lower for w in ["reminder", "schedule", "medicine", "appointment"]):
        today = datetime.now().strftime("%Y-%m-%d")
        rows  = conn.execute(
            "SELECT * FROM reminders "
            "WHERE patient_id=? AND scheduled_time LIKE ? AND status='pending'",
            (patient_id, f"{today}%")
        ).fetchall()
        if rows:
            items         = ", ".join(r["title"] for r in rows)
            response_text = f"You have {len(rows)} reminder(s) today: {items}."
        else:
            response_text = "You have no pending reminders today."

    elif "call" in command_lower and "caregiver" in command_lower:
        response_text = "Calling your caregiver now. Please wait."

    elif any(w in command_lower for w in ["who", "help", "what are you"]):
        response_text = (
            "I am ForgetMeNot, your personal assistant. "
            "I can remind you about medications and appointments, "
            "and help you recognize visitors."
        )

    elif "time" in command_lower:
        response_text = f"The current time is {datetime.now().strftime('%I:%M %p')}."

    elif "date" in command_lower or "today" in command_lower:
        response_text = f"Today is {datetime.now().strftime('%B %d, %Y')}."

    else:
        response_text = "I am sorry, I did not understand that. Please try again."

    # ── Generate MP3 via edge-tts ────────────────────────────────────────────
    audio_url = None
    try:
        filename_base = f"voice_resp_{uuid.uuid4()}"
        path          = local_tts(response_text, filename_base, language)
        audio_url     = f"/audio/{filename_base}.mp3"
    except Exception:
        pass   # text response still returned even if audio fails

    log_event(conn, patient_id, "voice_command", command[:100], response_text[:100])
    conn.commit()
    conn.close()

    return {
        "command":       command,
        "response_text": response_text,
        "audio_url":     audio_url,
        "language":      language,
        "voice":         VOICE_MAP.get(language, VOICE_MAP["en"]),
    }

@app.get("/audio/{filename}", tags=["Voice Assistant"])
def serve_audio(filename: str):
    """Serve a generated audio MP3 file."""
    path = os.path.join(AUDIO_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(404, "Audio not found")
    return FileResponse(path, media_type="audio/mpeg")

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 5 — ACTIVITY LOGS
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/logs/{patient_id}", tags=["Activity Logs"])
def get_logs(
    patient_id: str,
    date:       Optional[str] = None,
    event_type: Optional[str] = None,
):
    """
    Get activity logs for a patient (newest first).
    Optional filters:
      • ?date=YYYY-MM-DD
      • ?event_type=reminder_triggered | reminder_status | face_recognition |
                    voice_command | visitor_added | tts_generated
    """
    conn   = get_db()
    query  = "SELECT * FROM activity_logs WHERE patient_id=?"
    params = [patient_id]

    if date:
        query += " AND timestamp LIKE ?"
        params.append(f"{date}%")
    if event_type:
        query += " AND event_type=?"
        params.append(event_type)

    query += " ORDER BY timestamp DESC"
    rows   = conn.execute(query, params).fetchall()
    conn.close()
    return [row_to_dict(r) for r in rows]

@app.get("/logs/{patient_id}/summary", tags=["Activity Logs"])
def get_log_summary(patient_id: str):
    """Aggregated activity statistics for the caregiver dashboard."""
    conn  = get_db()
    today = datetime.now().strftime("%Y-%m-%d")

    total_logs = conn.execute(
        "SELECT COUNT(*) FROM activity_logs WHERE patient_id=?", (patient_id,)
    ).fetchone()[0]
    today_logs = conn.execute(
        "SELECT COUNT(*) FROM activity_logs WHERE patient_id=? AND timestamp LIKE ?",
        (patient_id, f"{today}%")
    ).fetchone()[0]
    face_ok = conn.execute(
        "SELECT COUNT(*) FROM activity_logs "
        "WHERE patient_id=? AND event_type='face_recognition' AND result='success'",
        (patient_id,)
    ).fetchone()[0]
    rem_done = conn.execute(
        "SELECT COUNT(*) FROM reminders WHERE patient_id=? AND status='completed'",
        (patient_id,)
    ).fetchone()[0]
    rem_missed = conn.execute(
        "SELECT COUNT(*) FROM reminders WHERE patient_id=? AND status='missed'",
        (patient_id,)
    ).fetchone()[0]
    conn.close()

    return {
        "patient_id":                patient_id,
        "total_logs":                total_logs,
        "today_logs":                today_logs,
        "face_recognitions_success": face_ok,
        "reminders_completed":       rem_done,
        "reminders_missed":          rem_missed,
    }

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 6 — CAREGIVER DASHBOARD
# ═══════════════════════════════════════════════════════════════════════════════

@app.get("/dashboard/{patient_id}", tags=["Caregiver Dashboard"])
def get_dashboard(patient_id: str):
    """
    Full caregiver dashboard in one API call:
    • Patient info
    • Today's reminders (total / completed / missed / pending + full list)
    • Total visitor count
    • Last 10 activity log entries
    """
    conn    = get_db()
    patient = conn.execute(
        "SELECT * FROM patients WHERE patient_id=?", (patient_id,)
    ).fetchone()
    if not patient:
        raise HTTPException(404, "Patient not found")

    today       = datetime.now().strftime("%Y-%m-%d")
    rem_rows    = conn.execute(
        "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ?",
        (patient_id, f"{today}%")
    ).fetchall()
    recent_logs = conn.execute(
        "SELECT * FROM activity_logs WHERE patient_id=? ORDER BY timestamp DESC LIMIT 10",
        (patient_id,)
    ).fetchall()
    visitor_count = conn.execute(
        "SELECT COUNT(*) FROM visitors WHERE patient_id=?", (patient_id,)
    ).fetchone()[0]

    reminders = [row_to_dict(r) for r in rem_rows]
    conn.close()

    return {
        "patient": row_to_dict(patient),
        "today_reminders": {
            "total":     len(reminders),
            "completed": sum(1 for r in reminders if r["status"] == "completed"),
            "missed":    sum(1 for r in reminders if r["status"] == "missed"),
            "pending":   sum(1 for r in reminders if r["status"] == "pending"),
            "items":     reminders,
        },
        "visitor_count": visitor_count,
        "recent_logs":   [row_to_dict(l) for l in recent_logs],
    }

@app.get("/dashboard/all/patients", tags=["Caregiver Dashboard"])
def get_all_patients_summary():
    """
    Quick summary of ALL patients — for caregivers managing multiple patients.
    Shows pending reminder count per patient for today.
    """
    conn     = get_db()
    patients = conn.execute("SELECT * FROM patients").fetchall()
    today    = datetime.now().strftime("%Y-%m-%d")
    result   = []
    for p in patients:
        pid     = p["patient_id"]
        pending = conn.execute(
            "SELECT COUNT(*) FROM reminders "
            "WHERE patient_id=? AND status='pending' AND scheduled_time LIKE ?",
            (pid, f"{today}%")
        ).fetchone()[0]
        result.append({**row_to_dict(p), "pending_reminders_today": pending})
    conn.close()
    return result

# ═══════════════════════════════════════════════════════════════════════════════
#  MODULE 7 — SETTINGS
# ═══════════════════════════════════════════════════════════════════════════════

SETTINGS_FILE = os.path.join(BASE, "data", "settings.json")

def load_settings() -> dict:
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    return {}

def save_settings(data: dict):
    with open(SETTINGS_FILE, "w") as f:
        json.dump(data, f, indent=2)

@app.get("/settings/{patient_id}", tags=["Settings"])
def get_settings(patient_id: str):
    """Get per-patient app settings."""
    settings = load_settings()
    return settings.get(patient_id, {
        "language":                    "en",
        "auto_recognition":            True,
        "recognition_cooldown_seconds": 60,
        "reminder_snooze_minutes":     5,
        "tts_voice_en":                VOICE_MAP["en"],
        "tts_voice_ur":                VOICE_MAP["ur"],
    })

@app.put("/settings/{patient_id}", tags=["Settings"])
def update_settings(
    patient_id:                   str,
    language:                     Optional[str]  = Form("en"),
    auto_recognition:             Optional[bool] = Form(True),
    recognition_cooldown_seconds: Optional[int]  = Form(60),
    reminder_snooze_minutes:      Optional[int]  = Form(5),
):
    """
    Update settings for a patient:
    • language                      — "en" | "ur"
    • auto_recognition              — true | false
    • recognition_cooldown_seconds  — seconds before same face re-triggers (default 60)
    • reminder_snooze_minutes       — snooze duration in minutes (default 5)
    """
    settings = load_settings()
    settings[patient_id] = {
        "language":                    language,
        "auto_recognition":            auto_recognition,
        "recognition_cooldown_seconds": recognition_cooldown_seconds,
        "reminder_snooze_minutes":     reminder_snooze_minutes,
        "tts_voice_en":                VOICE_MAP["en"],
        "tts_voice_ur":                VOICE_MAP["ur"],
    }
    save_settings(settings)
    return {"message": "Settings updated", "settings": settings[patient_id]}

# ── Mobile web UI (phone-sized interface; same origin as API for WebView / browser) ──
app.mount(
    "/mobile",
    StaticFiles(directory=MOBILE_DIR, html=True),
    name="mobile",
)

# ── Startup / Shutdown ────────────────────────────────────────────────────────
@app.on_event("startup")
def on_startup():
    print("\n🧠  ForgetMeNot Backend Started")
    print("🔊  TTS Engine : edge-tts  (en-US-JennyNeural | ur-PK-UzmaNeural)")
    print("📋  Modules    : Patient | Reminders | Face Recognition | TTS | Logs | Dashboard")
    print("📱  Mobile UI  : http://127.0.0.1:8000/mobile/")
    print("📍  Swagger UI : http://127.0.0.1:8000/docs")
    print("📲  Physical phone: uvicorn --host 0.0.0.0 … then flutter run --dart-define=API_BASE=http://<PC_IP>:8000\n")

@app.on_event("shutdown")
def on_shutdown():
    scheduler.shutdown()
    print("ForgetMeNot Backend Stopped")

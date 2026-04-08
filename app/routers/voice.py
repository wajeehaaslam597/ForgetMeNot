import os
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Form, HTTPException
from fastapi.responses import FileResponse

from ..core.db import get_db
from ..core.helpers import log_event
from ..core.paths import AUDIO_DIR
from ..core.tts import VOICE_MAP, local_tts

router = APIRouter(tags=["Voice Assistant"])


@router.post("/voice/tts")
def generate_tts(text: str = Form(...), language: str = Form("en"), patient_id: Optional[str] = Form(None)):
    try:
        filename_base = f"tts_{uuid.uuid4()}"
        path = local_tts(text, filename_base, language)
        if patient_id:
            conn = get_db()
            log_event(conn, patient_id, "tts_generated", text[:100], language)
            conn.commit()
            conn.close()
        return FileResponse(path, media_type="audio/mpeg", filename=f"{filename_base}.mp3")
    except Exception as e:
        raise HTTPException(500, f"TTS failed: {str(e)}")


@router.post("/voice/reminder-audio/{reminder_id}")
def generate_reminder_audio(reminder_id: str, language: str = "en"):
    conn = get_db()
    r = conn.execute("SELECT * FROM reminders WHERE reminder_id=?", (reminder_id,)).fetchone()
    conn.close()
    if not r:
        raise HTTPException(404, "Reminder not found")
    text = r["voice_message"] or f"Reminder: {r['title']}"
    try:
        path = local_tts(text, f"reminder_{reminder_id}", language)
        return FileResponse(path, media_type="audio/mpeg", filename=f"reminder_{reminder_id}.mp3")
    except Exception as e:
        raise HTTPException(500, f"TTS failed: {str(e)}")


@router.post("/voice/recognize-response")
def voice_command_response(command: str = Form(...), patient_id: str = Form(...), language: str = Form("en")):
    command_lower = command.lower().strip()
    conn = get_db()

    if any(w in command_lower for w in ["reminder", "schedule", "medicine", "appointment"]):
        today = datetime.now().strftime("%Y-%m-%d")
        rows = conn.execute(
            "SELECT * FROM reminders WHERE patient_id=? AND scheduled_time LIKE ? AND status='pending'",
            (patient_id, f"{today}%"),
        ).fetchall()
        response_text = (
            f"You have {len(rows)} reminder(s) today: {', '.join(r['title'] for r in rows)}."
            if rows
            else "You have no pending reminders today."
        )
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

    audio_url = None
    try:
        filename_base = f"voice_resp_{uuid.uuid4()}"
        local_tts(response_text, filename_base, language)
        audio_url = f"/audio/{filename_base}.mp3"
    except Exception:
        pass

    log_event(conn, patient_id, "voice_command", command[:100], response_text[:100])
    conn.commit()
    conn.close()
    return {
        "command": command,
        "response_text": response_text,
        "audio_url": audio_url,
        "language": language,
        "voice": VOICE_MAP.get(language, VOICE_MAP["en"]),
    }


@router.get("/audio/{filename}")
def serve_audio(filename: str):
    path = os.path.join(AUDIO_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(404, "Audio not found")
    return FileResponse(path, media_type="audio/mpeg")


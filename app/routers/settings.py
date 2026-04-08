import json
import os
from typing import Optional

from fastapi import APIRouter, Form

from ..core.paths import SETTINGS_FILE
from ..core.tts import VOICE_MAP

router = APIRouter(tags=["Settings"])


def load_settings() -> dict:
    if os.path.exists(SETTINGS_FILE):
        with open(SETTINGS_FILE) as f:
            return json.load(f)
    return {}


def save_settings(data: dict):
    with open(SETTINGS_FILE, "w") as f:
        json.dump(data, f, indent=2)


@router.get("/settings/{patient_id}")
def get_settings(patient_id: str):
    settings = load_settings()
    return settings.get(
        patient_id,
        {
            "language": "en",
            "auto_recognition": True,
            "recognition_cooldown_seconds": 60,
            "reminder_snooze_minutes": 5,
            "tts_voice_en": VOICE_MAP["en"],
            "tts_voice_ur": VOICE_MAP["ur"],
        },
    )


@router.put("/settings/{patient_id}")
def update_settings(
    patient_id: str,
    language: Optional[str] = Form("en"),
    auto_recognition: Optional[bool] = Form(True),
    recognition_cooldown_seconds: Optional[int] = Form(60),
    reminder_snooze_minutes: Optional[int] = Form(5),
):
    settings = load_settings()
    settings[patient_id] = {
        "language": language,
        "auto_recognition": auto_recognition,
        "recognition_cooldown_seconds": recognition_cooldown_seconds,
        "reminder_snooze_minutes": reminder_snooze_minutes,
        "tts_voice_en": VOICE_MAP["en"],
        "tts_voice_ur": VOICE_MAP["ur"],
    }
    save_settings(settings)
    return {"message": "Settings updated", "settings": settings[patient_id]}


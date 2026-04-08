from fastapi import APIRouter

router = APIRouter(tags=["Health"])


@router.get("/")
def root():
    return {
        "app": "ForgetMeNot",
        "status": "running",
        "version": "1.0.0",
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
        ],
    }


import os
import socket

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


def _check_tcp(host: str, port: int, timeout: float = 1.5) -> dict:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return {"status": "up", "target": f"{host}:{port}"}
    except OSError as exc:
        return {"status": "down", "target": f"{host}:{port}", "error": str(exc)}


@router.get("/health/services")
def service_health():
    checks = {
        "api": {"status": "up"},
        "postgres": _check_tcp(os.getenv("POSTGRES_HOST", "postgres"), int(os.getenv("POSTGRES_PORT", "5432"))),
        "qdrant": _check_tcp(os.getenv("QDRANT_HOST", "qdrant"), int(os.getenv("QDRANT_PORT", "6333"))),
        "redis": _check_tcp(os.getenv("REDIS_HOST", "redis"), int(os.getenv("REDIS_PORT", "6379"))),
        "minio": _check_tcp(os.getenv("MINIO_HOST", "minio"), int(os.getenv("MINIO_PORT", "9000"))),
    }
    overall = "up" if all(service["status"] == "up" for service in checks.values()) else "degraded"
    return {"status": overall, "services": checks}


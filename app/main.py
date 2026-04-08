from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .core.db import init_db
from .core.paths import MOBILE_DIR, ensure_dirs
from .core.scheduler import start_scheduler, stop_scheduler
from .routers.dashboard import router as dashboard_router
from .routers.health import router as health_router
from .routers.logs import router as logs_router
from .routers.patients import router as patients_router
from .routers.reminders import router as reminders_router
from .routers.settings import router as settings_router
from .routers.visitors import router as visitors_router
from .routers.voice import router as voice_router

ensure_dirs()
init_db()
start_scheduler()

app = FastAPI(
    title="ForgetMeNot API",
    description="Alzheimer's Assistive App Backend - FYP COMSATS",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health_router)
app.include_router(patients_router)
app.include_router(reminders_router)
app.include_router(visitors_router)
app.include_router(voice_router)
app.include_router(logs_router)
app.include_router(dashboard_router)
app.include_router(settings_router)

app.mount("/mobile", StaticFiles(directory=MOBILE_DIR, html=True), name="mobile")


@app.on_event("startup")
def on_startup():
    print("\nForgetMeNot Backend Started")
    print("TTS Engine : edge-tts  (en-US-JennyNeural | ur-PK-UzmaNeural)")
    print("Modules    : Patient | Reminders | Face Recognition | TTS | Logs | Dashboard")
    print("Mobile UI  : http://127.0.0.1:8000/mobile/")
    print("Swagger UI : http://127.0.0.1:8000/docs\n")


@app.on_event("shutdown")
def on_shutdown():
    stop_scheduler()
    print("ForgetMeNot Backend Stopped")


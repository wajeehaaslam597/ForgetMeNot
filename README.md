# ForgetMeNot — Backend API
## Alzheimer's Assistive App | FYP COMSATS Lahore | Session 2025-2026

---

## 🚀 How to Run

```bash
# 1. Install dependencies
pip install -r requirements.txt

# 2. Start the server
uvicorn main:app --reload --host 0.0.0.0 --port 8000

# 3. Open interactive API docs
http://localhost:8000/docs
```

---

## 📦 Modules Covered

| Module | Description |
|--------|-------------|
| Patient Management | Create / read / update / delete patient profiles |
| Reminder System | Schedule reminders (one-time, daily, weekly) with TTS voice messages |
| Face Recognition | Register visitor photos → real-time recognition via DeepFace (Facenet) |
| Voice Assistant (TTS) | Google TTS - generates .mp3 audio for reminders and recognition results |
| Activity Logs | All events logged automatically; caregiver can filter by date/type |
| Caregiver Dashboard | Full dashboard data in one API call |
| Settings | Language (en/ur), auto-recognition toggle, cooldown config |

---

## 📡 API Endpoints

### 👤 Patient Management
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/patients` | Create patient profile |
| GET | `/patients` | List all patients |
| GET | `/patients/{id}` | Get patient details |
| PUT | `/patients/{id}` | Update patient |
| POST | `/patients/{id}/photo` | Upload patient photo |
| DELETE | `/patients/{id}` | Delete patient |

### ⏰ Reminder System
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/reminders` | Create reminder |
| GET | `/reminders/{patient_id}` | Get all reminders (filter by `?date=YYYY-MM-DD`) |
| GET | `/reminders/{patient_id}/today` | Today's reminders summary |
| PUT | `/reminders/{id}/status` | Mark done/missed/snoozed |
| DELETE | `/reminders/{id}` | Delete reminder |

### 👁️ Face Recognition
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/visitors` | Register visitor |
| POST | `/visitors/{id}/photos` | Upload visitor photo (generates embedding) |
| GET | `/visitors/{patient_id}` | List visitors |
| POST | `/face/recognize/{patient_id}` | **Recognize face** from uploaded image |
| DELETE | `/visitors/{id}` | Delete visitor |

### 🔊 Voice Assistant (TTS)
| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/voice/tts` | Generate audio from any text (en/ur) |
| POST | `/voice/reminder-audio/{id}` | Get audio for a specific reminder |
| POST | `/voice/recognize-response` | Process voice command → text + audio response |
| GET | `/audio/{filename}` | Serve audio file |

### 📋 Activity Logs
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/logs/{patient_id}` | Get logs (filter by `?date=` and `?event_type=`) |
| GET | `/logs/{patient_id}/summary` | Stats summary |

### 📊 Caregiver Dashboard
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/dashboard/{patient_id}` | Full dashboard: patient + reminders + logs + visitors |
| GET | `/dashboard/all/patients` | All patients quick summary |

### ⚙️ Settings
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/settings/{patient_id}` | Get settings |
| PUT | `/settings/{patient_id}` | Update language, auto-recognition, etc. |

---

## 🧠 Face Recognition Flow

```
Caregiver uploads visitor photos
        ↓
DeepFace (Facenet) generates 128-dim embeddings
        ↓
Embeddings saved as .json files on disk
        ↓
Patient opens camera → frame uploaded to /face/recognize/{patient_id}
        ↓
Cosine similarity vs all stored visitor embeddings
        ↓
If similarity ≥ 0.70 → announce name + relationship via TTS
Else → "Could not recognize this person"
```

---

## 🎙️ Voice Commands (via /voice/recognize-response)

| Command | Response |
|---------|----------|
| "what are my reminders" | Lists today's pending reminders |
| "call my caregiver" | Initiates caregiver call |
| "what time is it" | Current time |
| "what is today's date" | Today's date |
| "help" / "who are you" | App introduction |

---

## 🗄️ Database (SQLite - `data/forgetmenot.db`)

- `patients` — patient profiles
- `reminders` — scheduled reminders with status tracking
- `visitors` — registered visitors per patient
- `visitor_photos` — photo paths per visitor
- `activity_logs` — all events (reminders, face recognition, voice commands)

---

## 🔒 Architecture

```
Mobile App (Flutter/React Native)
           ↕ HTTP/JSON
    FastAPI Backend (This server)
    ├── SQLite (data storage)
    ├── DeepFace (face recognition)
    ├── gTTS (voice synthesis)
    └── APScheduler (reminder checks every 30s)
```

---

## 👥 Team — ForgetMeNot
- Sadia Shakoor (SP23-BAI-047) — Group Leader
- Mutawiffah Mudassar Khan (SP23-BAI-044)
- Wajeeha Aslam (SP23-BAI-054)

**Supervisor:** Dr. Ashfaq Ahmed | **Co-Supervisor:** Ms. Fareeha Iftikhar  
**COMSATS University Islamabad, Lahore Campus**

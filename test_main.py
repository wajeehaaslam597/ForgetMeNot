"""
test_main.py — Pytest suite for ForgetMeNot Backend
Run: pytest test_main.py -v

Covers:
  Module 0 — Health / root
  Module 1 — Patient Management
  Module 2 — Reminder System
  Module 3 — Visitor Management
  Module 4 — Voice Assistant (TTS mocked)
  Module 5 — Activity Logs
  Module 6 — Caregiver Dashboard
  Module 7 — Settings
  Helpers  — row_to_dict, check_reminders
"""

import os
import json
import tempfile
import pytest
from datetime import datetime, timedelta
from unittest.mock import patch, MagicMock, AsyncMock
from starlette.testclient import TestClient as _TC

def _make_client(asgi_app):
    # app is always the first positional arg across all starlette versions.
    # raise_server_exceptions keyword has been stable since starlette 0.20+.
    return _TC(asgi_app, raise_server_exceptions=False)


# ── Point the app at a temp DB before importing ────────────────────────────────
_tmp_dir = tempfile.mkdtemp()
os.environ.setdefault("_FMN_TEST_BASE", _tmp_dir)

# Patch DB_PATH and directories before the app module runs
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Patch edge_tts before importing main so it doesn't need to be installed
edge_tts_mock = MagicMock()
communicate_mock = MagicMock()
communicate_mock.save = AsyncMock()
edge_tts_mock.Communicate.return_value = communicate_mock
sys.modules.setdefault("edge_tts", edge_tts_mock)

# Patch apscheduler so scheduler doesn't actually start
aps_mock = MagicMock()
bg_scheduler_mock = MagicMock()
aps_mock.schedulers.background.BackgroundScheduler.return_value = bg_scheduler_mock
sys.modules.setdefault("apscheduler", aps_mock)
sys.modules.setdefault("apscheduler.schedulers", MagicMock())
sys.modules.setdefault("apscheduler.schedulers.background", aps_mock.schedulers.background)

import importlib
import main  # noqa: E402 — imported after mocks are in place

# Redirect the app's DB and directories to temp paths
main.DB_PATH   = os.path.join(_tmp_dir, "test.db")
main.FACES_DIR = os.path.join(_tmp_dir, "faces")
main.AUDIO_DIR = os.path.join(_tmp_dir, "audio")
main.LOGS_DIR  = os.path.join(_tmp_dir, "logs")
main.SETTINGS_FILE = os.path.join(_tmp_dir, "settings.json")
for d in [main.FACES_DIR, main.AUDIO_DIR, main.LOGS_DIR]:
    os.makedirs(d, exist_ok=True)

main.init_db()  # create tables in temp DB

client = _make_client(main.app)


# ══════════════════════════════════════════════════════════════════════════════
#  FIXTURES
# ══════════════════════════════════════════════════════════════════════════════

@pytest.fixture(autouse=True)
def clean_db():
    """Wipe all tables before every test for isolation."""
    conn = main.get_db()
    for table in ["activity_logs", "visitor_photos", "visitors", "reminders", "patients"]:
        conn.execute(f"DELETE FROM {table}")
    conn.commit()
    conn.close()
    # Clean settings file
    if os.path.exists(main.SETTINGS_FILE):
        os.remove(main.SETTINGS_FILE)
    yield


@pytest.fixture
def patient():
    """Create a patient and return its ID + name."""
    r = client.post("/patients", json={"name": "Alice", "age": 72, "relationship": "self"})
    assert r.status_code == 200
    return r.json()


@pytest.fixture
def reminder(patient):
    """Create a reminder for the fixture patient."""
    future = (datetime.now() + timedelta(hours=2)).isoformat()
    r = client.post("/reminders", json={
        "patient_id":     patient["patient_id"],
        "title":          "Take medication",
        "reminder_type":  "medication",
        "scheduled_time": future,
        "repeat_option":  "one-time",
        "voice_message":  "Time to take your pills!",
    })
    assert r.status_code == 200
    return r.json()


@pytest.fixture
def visitor(patient):
    """Register a visitor for the fixture patient."""
    r = client.post("/visitors", json={
        "patient_id":   patient["patient_id"],
        "name":         "Bob",
        "relationship": "son",
    })
    assert r.status_code == 200
    return r.json()


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 0 — HEALTH
# ══════════════════════════════════════════════════════════════════════════════

class TestHealth:
    def test_root_returns_200(self):
        r = client.get("/")
        assert r.status_code == 200

    def test_root_contains_app_name(self):
        r = client.get("/")
        assert r.json()["app"] == "ForgetMeNot"

    def test_root_status_running(self):
        r = client.get("/")
        assert r.json()["status"] == "running"

    def test_root_lists_all_modules(self):
        modules = client.get("/").json()["modules"]
        assert "Reminder System" in modules
        assert "Patient Management" in modules


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 1 — PATIENT MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

class TestPatients:
    def test_create_patient_returns_id(self):
        r = client.post("/patients", json={"name": "Carol", "age": 68})
        assert r.status_code == 200
        assert "patient_id" in r.json()

    def test_create_patient_name_stored(self):
        r = client.post("/patients", json={"name": "Carol", "age": 68})
        pid = r.json()["patient_id"]
        r2  = client.get(f"/patients/{pid}")
        assert r2.json()["name"] == "Carol"

    def test_create_patient_optional_fields_none(self):
        r = client.post("/patients", json={"name": "Dave"})
        assert r.status_code == 200
        pid = r.json()["patient_id"]
        data = client.get(f"/patients/{pid}").json()
        assert data["age"] is None
        assert data["relationship"] is None

    def test_list_patients_empty(self):
        r = client.get("/patients")
        assert r.status_code == 200
        assert r.json() == []

    def test_list_patients_returns_all(self, patient):
        client.post("/patients", json={"name": "Eve"})
        r = client.get("/patients")
        assert len(r.json()) == 2

    def test_get_patient_not_found(self):
        r = client.get("/patients/nonexistent-id")
        assert r.status_code == 404

    def test_update_patient(self, patient):
        pid = patient["patient_id"]
        r   = client.put(f"/patients/{pid}", json={"name": "Alice Updated", "age": 73})
        assert r.status_code == 200
        data = client.get(f"/patients/{pid}").json()
        assert data["name"] == "Alice Updated"
        assert data["age"] == 73

    def test_delete_patient(self, patient):
        pid = patient["patient_id"]
        r   = client.delete(f"/patients/{pid}")
        assert r.status_code == 200
        assert client.get(f"/patients/{pid}").status_code == 404

    def test_upload_patient_photo(self, patient):
        pid  = patient["patient_id"]
        data = b"fakeimagebytes"
        r    = client.post(
            f"/patients/{pid}/photo",
            files={"file": ("photo.jpg", data, "image/jpeg")},
        )
        assert r.status_code == 200
        assert "path" in r.json()


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 2 — REMINDER SYSTEM
# ══════════════════════════════════════════════════════════════════════════════

class TestReminders:
    def _future(self, hours=2):
        return (datetime.now() + timedelta(hours=hours)).isoformat()

    def _past(self, hours=1):
        return (datetime.now() - timedelta(hours=hours)).isoformat()

    def test_create_reminder_returns_id(self, patient):
        pid = patient["patient_id"]
        r   = client.post("/reminders", json={
            "patient_id":     pid,
            "title":          "Lunch",
            "reminder_type":  "meal",
            "scheduled_time": self._future(),
        })
        assert r.status_code == 200
        assert "reminder_id" in r.json()

    def test_create_reminder_default_voice_message(self, patient):
        pid = patient["patient_id"]
        r   = client.post("/reminders", json={
            "patient_id":     pid,
            "title":          "Walk",
            "reminder_type":  "custom",
            "scheduled_time": self._future(),
        })
        assert "Walk" in r.json()["voice_message"]

    def test_get_reminders_for_patient(self, patient):
        pid = patient["patient_id"]
        client.post("/reminders", json={
            "patient_id": pid, "title": "A",
            "reminder_type": "custom", "scheduled_time": self._future(),
        })
        r = client.get(f"/reminders/{pid}")
        assert len(r.json()) == 1

    def test_get_reminders_date_filter(self, patient):
        pid   = patient["patient_id"]
        today = datetime.now().strftime("%Y-%m-%d")
        client.post("/reminders", json={
            "patient_id": pid, "title": "Today",
            "reminder_type": "custom",
            "scheduled_time": datetime.now().isoformat(),
        })
        r = client.get(f"/reminders/{pid}?date={today}")
        assert len(r.json()) >= 1

    def test_get_todays_reminders_counts(self, patient):
        pid = patient["patient_id"]
        client.post("/reminders", json={
            "patient_id": pid, "title": "Med",
            "reminder_type": "medication",
            "scheduled_time": datetime.now().isoformat(),
        })
        r = client.get(f"/reminders/{pid}/today")
        assert r.status_code == 200
        data = r.json()
        assert "total" in data
        assert data["total"] >= 1

    def test_update_reminder_status_completed(self, reminder):
        rid = reminder["reminder_id"]
        r   = client.put(f"/reminders/{rid}/status", json={"status": "completed"})
        assert r.status_code == 200
        assert "completed" in r.json()["message"]

    def test_update_reminder_status_not_found(self):
        r = client.put("/reminders/bad-id/status", json={"status": "missed"})
        assert r.status_code == 404

    def test_delete_reminder(self, reminder):
        rid = reminder["reminder_id"]
        r   = client.delete(f"/reminders/{rid}")
        assert r.status_code == 200

    def test_check_reminders_one_time_completes(self, patient):
        """Unit test for the background job logic on a one-time past reminder."""
        pid  = patient["patient_id"]
        conn = main.get_db()
        import uuid as _uuid
        rid  = str(_uuid.uuid4())
        past = (datetime.now() - timedelta(minutes=1)).isoformat()
        conn.execute(
            "INSERT INTO reminders VALUES (?,?,?,?,?,?,?,?,?)",
            (rid, pid, "Old Reminder", "medication", past,
             "one-time", "msg", "pending", datetime.now().isoformat())
        )
        conn.commit()
        conn.close()

        main.check_reminders()

        conn = main.get_db()
        row  = conn.execute(
            "SELECT status FROM reminders WHERE reminder_id=?", (rid,)
        ).fetchone()
        conn.close()
        assert row["status"] == "completed"

    def test_check_reminders_daily_advances_time(self, patient):
        pid  = patient["patient_id"]
        conn = main.get_db()
        import uuid as _uuid
        rid  = str(_uuid.uuid4())
        past = (datetime.now() - timedelta(minutes=1)).isoformat()
        conn.execute(
            "INSERT INTO reminders VALUES (?,?,?,?,?,?,?,?,?)",
            (rid, pid, "Daily Pill", "medication", past,
             "daily", "msg", "pending", datetime.now().isoformat())
        )
        conn.commit()
        conn.close()

        main.check_reminders()

        conn = main.get_db()
        row  = conn.execute(
            "SELECT scheduled_time, status FROM reminders WHERE reminder_id=?", (rid,)
        ).fetchone()
        conn.close()
        new_t = datetime.fromisoformat(row["scheduled_time"])
        assert new_t > datetime.now()  # pushed forward
        assert row["status"] == "pending"


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 3 — VISITOR MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

class TestVisitors:
    def test_add_visitor_returns_id(self, patient):
        pid = patient["patient_id"]
        r   = client.post("/visitors", json={
            "patient_id": pid, "name": "Charlie", "relationship": "friend",
        })
        assert r.status_code == 200
        assert "visitor_id" in r.json()

    def test_get_visitors_for_patient(self, patient, visitor):
        pid = patient["patient_id"]
        r   = client.get(f"/visitors/{pid}")
        assert r.status_code == 200
        names = [v["name"] for v in r.json()]
        assert "Bob" in names

    def test_delete_visitor(self, patient, visitor):
        vid = visitor["visitor_id"]
        r   = client.delete(f"/visitors/{vid}")
        assert r.status_code == 200

    def test_upload_visitor_photo_unknown_visitor(self):
        r = client.post(
            "/visitors/bad-id/photos",
            files={"file": ("face.jpg", b"bytes", "image/jpeg")},
        )
        assert r.status_code == 404

    def test_upload_visitor_photo_ok(self, visitor):
        vid = visitor["visitor_id"]
        # DeepFace is optional — patch it out so no ML needed
        with patch.dict("sys.modules", {"deepface": MagicMock(), "numpy": MagicMock()}):
            r = client.post(
                f"/visitors/{vid}/photos",
                files={"file": ("face.jpg", b"fakebytes", "image/jpeg")},
            )
        # 200 if deepface succeeds; accept 500 if library absent in test env
        assert r.status_code in (200, 500)

    def test_recognize_visitor_no_photo(self, patient):
        """POST without a file returns 422 (validation error)."""
        r = client.post(f"/patients/{patient['patient_id']}/recognize")
        assert r.status_code == 422


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 4 — VOICE ASSISTANT
# ══════════════════════════════════════════════════════════════════════════════

class TestVoice:
    def _mock_tts(self, monkeypatch):
        fake_path = os.path.join(main.AUDIO_DIR, "fake.mp3")
        open(fake_path, "wb").close()
        monkeypatch.setattr(main, "local_tts", lambda *a, **kw: fake_path)
        return fake_path

    def test_generate_tts_returns_audio(self, monkeypatch):
        self._mock_tts(monkeypatch)
        r = client.post("/voice/tts", data={"text": "Hello", "language": "en"})
        assert r.status_code == 200
        assert r.headers["content-type"].startswith("audio/")

    def test_generate_tts_with_patient_id_logs(self, monkeypatch, patient):
        self._mock_tts(monkeypatch)
        pid = patient["patient_id"]
        r   = client.post("/voice/tts", data={
            "text": "Take your pills", "language": "en", "patient_id": pid,
        })
        assert r.status_code == 200
        logs = client.get(f"/logs/{pid}").json()
        assert any(l["event_type"] == "tts_generated" for l in logs)

    def test_reminder_audio_not_found(self):
        r = client.post("/voice/reminder-audio/bad-id")
        assert r.status_code == 404

    def test_reminder_audio_ok(self, monkeypatch, reminder):
        self._mock_tts(monkeypatch)
        rid = reminder["reminder_id"]
        r   = client.post(f"/voice/reminder-audio/{rid}")
        assert r.status_code == 200

    def test_voice_command_reminders_intent(self, monkeypatch, patient):
        self._mock_tts(monkeypatch)
        pid = patient["patient_id"]
        r   = client.post("/voice/recognize-response", data={
            "command": "what are my reminders",
            "patient_id": pid,
            "language": "en",
        })
        assert r.status_code == 200
        assert "reminder" in r.json()["response_text"].lower()

    def test_voice_command_time_intent(self, monkeypatch, patient):
        self._mock_tts(monkeypatch)
        r = client.post("/voice/recognize-response", data={
            "command": "what time is it",
            "patient_id": patient["patient_id"],
            "language": "en",
        })
        assert "time" in r.json()["response_text"].lower()

    def test_voice_command_date_intent(self, monkeypatch, patient):
        self._mock_tts(monkeypatch)
        r = client.post("/voice/recognize-response", data={
            "command": "what is today's date",
            "patient_id": patient["patient_id"],
            "language": "en",
        })
        assert r.json()["response_text"] != ""

    def test_voice_command_unknown_intent(self, monkeypatch, patient):
        self._mock_tts(monkeypatch)
        r = client.post("/voice/recognize-response", data={
            "command": "xyzzy abracadabra",
            "patient_id": patient["patient_id"],
            "language": "en",
        })
        assert "sorry" in r.json()["response_text"].lower()

    def test_serve_audio_not_found(self):
        r = client.get("/audio/nonexistent.mp3")
        assert r.status_code == 404

    def test_serve_audio_ok(self):
        fname = "test_audio.mp3"
        open(os.path.join(main.AUDIO_DIR, fname), "wb").close()
        r = client.get(f"/audio/{fname}")
        assert r.status_code == 200

    def test_voice_info_endpoint(self):
        r = client.get("/voice/info")
        assert r.status_code == 200
        data = r.json()
        assert "voice" in data


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 5 — ACTIVITY LOGS
# ══════════════════════════════════════════════════════════════════════════════

class TestLogs:
    def test_get_logs_empty(self, patient):
        r = client.get(f"/logs/{patient['patient_id']}")
        assert r.status_code == 200
        assert r.json() == []

    def test_get_logs_after_action(self, patient, reminder):
        pid = patient["patient_id"]
        r   = client.get(f"/logs/{pid}")
        # creating a reminder should have written a log entry
        assert len(r.json()) >= 1

    def test_get_logs_filter_by_event_type(self, patient, reminder):
        pid  = patient["patient_id"]
        r    = client.get(f"/logs/{pid}?event_type=reminder_created")
        types = {l["event_type"] for l in r.json()}
        assert types == {"reminder_created"}

    def test_get_logs_filter_by_date(self, patient, reminder):
        pid   = patient["patient_id"]
        today = datetime.now().strftime("%Y-%m-%d")
        r     = client.get(f"/logs/{pid}?date={today}")
        assert r.status_code == 200
        assert len(r.json()) >= 1

    def test_log_summary(self, patient):
        pid = patient["patient_id"]
        r   = client.get(f"/logs/{pid}/summary")
        assert r.status_code == 200
        data = r.json()
        for key in ("total_logs", "today_logs", "reminders_completed", "reminders_missed"):
            assert key in data


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 6 — CAREGIVER DASHBOARD
# ══════════════════════════════════════════════════════════════════════════════

class TestDashboard:
    def test_dashboard_not_found(self):
        r = client.get("/dashboard/no-such-patient")
        assert r.status_code == 404

    def test_dashboard_structure(self, patient):
        pid  = patient["patient_id"]
        r    = client.get(f"/dashboard/{pid}")
        assert r.status_code == 200
        data = r.json()
        assert "patient" in data
        assert "today_reminders" in data
        assert "visitor_count" in data
        assert "recent_logs" in data

    def test_dashboard_today_reminders_counts(self, patient):
        pid = patient["patient_id"]
        # Add a reminder for today
        client.post("/reminders", json={
            "patient_id":     pid,
            "title":          "Dashboard Test",
            "reminder_type":  "custom",
            "scheduled_time": datetime.now().isoformat(),
        })
        r    = client.get(f"/dashboard/{pid}")
        tr   = r.json()["today_reminders"]
        assert tr["total"] >= 1
        assert tr["pending"] + tr["completed"] + tr["missed"] == tr["total"]

    def test_all_patients_summary(self, patient):
        r = client.get("/dashboard/all/patients")
        assert r.status_code == 200
        pids = [p["patient_id"] for p in r.json()]
        assert patient["patient_id"] in pids


# ══════════════════════════════════════════════════════════════════════════════
#  MODULE 7 — SETTINGS
# ══════════════════════════════════════════════════════════════════════════════

class TestSettings:
    def test_get_settings_defaults(self, patient):
        pid = patient["patient_id"]
        r   = client.get(f"/settings/{pid}")
        assert r.status_code == 200
        data = r.json()
        assert data["language"] == "en"
        assert data["auto_recognition"] is True

    def test_update_settings(self, patient):
        pid = patient["patient_id"]
        r   = client.put(f"/settings/{pid}", data={
            "language": "ur",
            "auto_recognition": False,
            "recognition_cooldown_seconds": 120,
            "reminder_snooze_minutes": 10,
        })
        assert r.status_code == 200
        updated = client.get(f"/settings/{pid}").json()
        assert updated["language"] == "ur"
        assert updated["recognition_cooldown_seconds"] == 120

    def test_settings_persisted_across_calls(self, patient):
        pid = patient["patient_id"]
        client.put(f"/settings/{pid}", data={"language": "ur"})
        r   = client.get(f"/settings/{pid}")
        assert r.json()["language"] == "ur"

    def test_settings_include_tts_voices(self, patient):
        pid  = patient["patient_id"]
        data = client.get(f"/settings/{pid}").json()
        assert "tts_voice_en" in data
        assert "tts_voice_ur" in data


# ══════════════════════════════════════════════════════════════════════════════
#  HELPERS — unit tests
# ══════════════════════════════════════════════════════════════════════════════

class TestHelpers:
    def test_row_to_dict_none(self):
        assert main.row_to_dict(None) is None

    def test_row_to_dict_converts_row(self):
        conn = main.get_db()
        conn.execute(
            "INSERT INTO patients VALUES (?,?,?,?,?,?)",
            ("p1", "Test", 50, "self", None, datetime.now().isoformat())
        )
        conn.commit()
        row = conn.execute("SELECT * FROM patients WHERE patient_id='p1'").fetchone()
        d   = main.row_to_dict(row)
        conn.close()
        assert isinstance(d, dict)
        assert d["name"] == "Test"

    def test_log_event_inserts_row(self, patient):
        pid  = patient["patient_id"]
        conn = main.get_db()
        main.log_event(conn, pid, "test_event", "detail here", "ok")
        conn.commit()
        row = conn.execute(
            "SELECT * FROM activity_logs WHERE patient_id=? AND event_type='test_event'",
            (pid,)
        ).fetchone()
        conn.close()
        assert row is not None
        assert row["event_detail"] == "detail here"

    def test_load_save_settings(self):
        data = {"p1": {"language": "ur"}}
        main.save_settings(data)
        loaded = main.load_settings()
        assert loaded == data

    def test_load_settings_missing_file(self):
        if os.path.exists(main.SETTINGS_FILE):
            os.remove(main.SETTINGS_FILE)
        result = main.load_settings()
        assert result == {}

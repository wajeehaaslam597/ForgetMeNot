from typing import Optional

from pydantic import BaseModel


class PatientCreate(BaseModel):
    name: str
    age: Optional[int] = None
    relationship: Optional[str] = None


class ReminderCreate(BaseModel):
    patient_id: str
    title: str
    reminder_type: str
    scheduled_time: str
    repeat_option: str = "one-time"
    voice_message: Optional[str] = None


class ReminderStatusUpdate(BaseModel):
    status: str


class VisitorCreate(BaseModel):
    patient_id: str
    name: str
    relationship: str


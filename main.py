# Import necessary modules and packages
from fastapi import FastAPI, HTTPException, Depends, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from fastapi.responses import JSONResponse
from pydantic import BaseModel, field_validator
import os
from datetime import datetime, timedelta, timezone
from contextlib import asynccontextmanager
from google.cloud import firestore
from firebase_admin import auth, credentials, firestore, initialize_app, messaging
import json
import logging
from typing import Optional
from zoneinfo import ZoneInfo

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK
cred = credentials.Certificate("firebaseKeys.json")
db_url = os.getenv("FIREBASE_REALTIME_DATABASE_URL",)
firebase_app = initialize_app(cred, {
    'databaseURL': db_url  # Add your RTDB URL if needed elsewhere
})
db = firestore.client()

# Security
security = HTTPBearer()

# Constants
LOW_INVENTORY_THRESHOLD = 5
NOTIFICATION_WINDOW_MINUTES = 15
# Note: RTDB constants removed as we now use Firestore exclusively

# ApScheduler for background tasks
from apscheduler.schedulers.asyncio import AsyncIOScheduler
scheduler = AsyncIOScheduler()

# Pydantic models
class TimeWindow(BaseModel):
    hour: int 
    minute: int
    
    @field_validator('hour', 'minute')
    def validate_time(cls, v):
        if not 0 <= v < 60:
            raise ValueError('Time values must be between 0-59')
        return v

class PrescriptionUpdate(BaseModel):
    slotNumber: str
    tabletName: str
    beforeFood: bool
    everyday: bool
    frequency: dict
    certainDays: dict
    dosage: int
    remainingCount: int

class NotificationSettings(BaseModel):
    reminders_enabled: bool = True
    low_inventory_alerts: bool = True
    missed_dose_alerts: bool = True

# Enhanced lifespan management
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Removed RTDB listener logic as we now read logs from Firestore only

    # Initialize scheduler
    scheduler.add_job(
        check_reminders, 
        trigger='interval', 
        minutes=1,
        max_instances=1,
        coalesce=True
    )
    scheduler.start()

    yield

    # Graceful shutdown
    scheduler.shutdown(wait=True)

app = FastAPI(
    lifespan=lifespan,
    title="Smart Pill Dispenser API",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Removed handle_rtdb_update since data is now read from Firestore directly

# Dependency for Firebase authentication
async def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security)):
    try:
        decoded_token = auth.verify_id_token(credentials.credentials)
        return decoded_token
    except Exception as e:
        logger.error(f"Authentication error: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid authentication credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

# Enhanced Prescription Management using Firestore only
@app.post("/prescriptions/{email}", status_code=status.HTTP_201_CREATED)
async def update_prescription(
    email: str,
    prescription_data: PrescriptionUpdate,
    user: dict = Depends(get_current_user)
):
    if user['email'] != email:
        raise HTTPException(status_code=403, detail="Unauthorized access")
    
    if prescription_data.dosage <= 0:
        raise HTTPException(status_code=400, detail="Invalid dosage amount")
    
    @firestore.transactional
    def update_prescription_tx(transaction, ref, data):
        transaction.set(ref, {data.slotNumber: data.model_dump()}, merge=True)
        
    prescription_ref = db.collection("USER").document(email) \
        .collection("prescriptions").document("defaultPrescription")
    
    try:
        update_prescription_tx(db.transaction(), prescription_ref, prescription_data)
        # Removed writing to RTDB; logic now uses Firestore intake_history
    except Exception as e:
        logger.error(f"Prescription update failed: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to update prescription")
    
    return {"status": "Prescription updated", "slot": prescription_data.slotNumber}

@app.get("/prescriptions/{email}/details", status_code=200)
async def get_prescription_details(email: str):
    prescription_ref = db.collection("USER").document(email) \
        .collection("prescriptions").document("defaultPrescription")
    doc = prescription_ref.get()
    
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Prescription data not found")
    
    prescription_data = doc.to_dict()
    prescriptions_list = []
    
    # Iterate through each slot (each key represents a slot) with its medication details
    for slot, details in prescription_data.items():
        if isinstance(details, dict):
            prescription_item = {
                "slotNumber": slot,
                "tabletName": details.get("tabletName", ""),
                "beforeFood": details.get("beforeFood"),
                "courseDuration": details.get("courseDuration"),
                "dosage": details.get("dosage"),
                "duration": details.get("duration"),
                "everyday": details.get("everyday"),
                "frequency": details.get("frequency"),
                "instructions": details.get("instructions"),
                "notes": details.get("notes"),
                "slotNumberAllocated": details.get("slotNumberAllocated"),
                "certainDays": details.get("certainDays"),
            }
            prescriptions_list.append(prescription_item)
    
    return {"prescriptions": prescriptions_list}

# Health Check updated to verify Firestore connectivity only
@app.get("/health")
async def health_check():
    try:
        # Verify Firestore connectivity
        db.collection("HEALTHCHECK").document("ping").set({"timestamp": datetime.utcnow()})
        return {"status": "ok", "services": ["firestore"]}
    except Exception as e:
        logger.error(f"Health check failed: {str(e)}")
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable"}
        )

# Enhanced notification scheduler with timezone awareness
async def check_reminders():
    logger.info("Running reminder check")
    
    users_ref = db.collection("USER")
    users = users_ref.stream()
    
    for user in users:
        try:
            user_email = user.id
            user_data = user.to_dict()
            
            # Check notification preferences
            settings = user_data.get("notification_settings", {})
            if not settings.get("reminders_enabled", True):
                continue
            
            # Get user's timezone
            user_tz = get_user_timezone(user_data)
            # Current time in user's timezone
            current_time_user_tz = datetime.now(user_tz)
            
            # Get time windows for this user
            time_windows = get_user_time_windows(user_email)
            intake_history_ref = user.reference.collection("intake_history")
            
            for period, window in time_windows.items():
                # Create the due time directly in user's timezone
                due_time = current_time_user_tz.replace(
                    hour=window["hour"],
                    minute=window["minute"],
                    second=0,
                    microsecond=0
                )
                
                # If due_time is in the past (for today), it will still work correctly
                
                # Check due notifications - window starts NOTIFICATION_WINDOW_MINUTES before due time
                window_start = due_time - timedelta(minutes=NOTIFICATION_WINDOW_MINUTES)
                window_end = due_time + timedelta(minutes=NOTIFICATION_WINDOW_MINUTES)
                
                # Only process if we're within the notification window
                if window_start <= current_time_user_tz <= window_end:
                    logger.info(f"Checking due notification for user {user_email} - {period}")
                    check_due_notification(user, period, due_time, intake_history_ref)
                
                # Check missed doses - after grace period
                if current_time_user_tz > window_end:
                    logger.info(f"Checking missed dose for user {user_email} - {period}")
                    check_missed_dose(user, period, due_time, intake_history_ref)
                    
        except Exception as e:
            logger.error(f"Error processing user {user.id}: {str(e)}", exc_info=True)

def get_user_time_windows(email: str):
    # Implementation to get user-specific time windows
    ref = db.collection("USER").document(email).collection("settings").document("defaultSettings")
    #inside the ref it has fields like morning : {hour: "", minute: ""}, afternoon : {hour: "", minute: ""}, night : {hour: "", minute: ""}
    return {
        "morning": ref.get().to_dict().get("morning", {"hour": 0, "minute": 0}),
        "afternoon": ref.get().to_dict().get("afternoon", {"hour": 0, "minute": 0}),
        "night": ref.get().to_dict().get("night", {"hour": 0, "minute": 0})
    }

# Function to check and send due notifications
def check_due_notification(user, period, due_time, intake_history_ref):
    user_data = user.to_dict()
    user_tz = get_user_timezone(user_data)
    
    # Get today's date in user's timezone
    today = datetime.now(user_tz).date().isoformat()
    intake_history_doc_ref = intake_history_ref.document(today)
    intake_history_doc = intake_history_doc_ref.get()
    
    if not intake_history_doc.exists:
        # Initialize intake history for today using new structure
        default_data = {
            p: {"taken": False, "notification_sent": False, "missed_notification_sent": False}
            for p in ["morning", "afternoon", "night"]
        }
        intake_history_doc_ref.set(default_data)
        intake_history_data = default_data
    else:
        intake_history_data = intake_history_doc.to_dict()
    
    period_data = intake_history_data.get(period, {})
    # Convert boolean fields into a dict without overwriting the "taken" status
    if isinstance(period_data, bool):
        period_data = {
            "taken": period_data,
            "notification_sent": False,
            "missed_notification_sent": False
        }
        # Save the updated structure back to the database
        intake_history_doc_ref.update({ period: period_data })
    
    taken = period_data.get("taken", False)
    notification_sent = period_data.get("notification_sent", False)
    
    # Current time in user's timezone - already have due_time in user's timezone from caller
    current_time_user_tz = datetime.now(user_tz)
    
    # Calculate the start of the notification window
    window_start = due_time - timedelta(minutes=NOTIFICATION_WINDOW_MINUTES)
    
    # Only send if not taken, notification not sent, and we're within the window
    if not taken and not notification_sent and current_time_user_tz >= window_start and current_time_user_tz <= due_time:
        # Send reminder notification
        user_doc = user.reference.get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            fcm_token = user_data.get("fcm_token")
            print("fcm token", fcm_token)
            settings = user_data.get("notification_settings", {})
            
            if settings.get("reminders_enabled", True) and fcm_token:
                send_fcm_notification(
                    fcm_token,
                    f"{period.capitalize()} Reminder",
                    "Time to take your medication!"
                )
                # Update intake history to mark notification as sent without overwriting other fields
                update_data = {f"{period}.notification_sent": True}
                intake_history_doc_ref.update(update_data)

# Helper function to get user's timezone as ZoneInfo
def get_user_timezone(user_data):
    tz_str = user_data.get("timezone")
    return ZoneInfo(tz_str) if tz_str else timezone.utc

# Function to check and send missed dose notifications
def check_missed_dose(user, period, due_time, intake_history_ref):
    user_data = user.to_dict()
    user_tz = get_user_timezone(user_data)
    
    today = datetime.now(user_tz).date().isoformat()
    intake_history_doc_ref = user.reference.collection("intake_history").document(today)
    intake_history_doc = intake_history_doc_ref.get()
    
    if not intake_history_doc.exists:
        default_data = {
            period: {"taken": False, "notification_sent": False, "missed_notification_sent": False}
            for period in ["morning", "afternoon", "night"]
        }
        intake_history_doc_ref.set(default_data)
        intake_history_data = default_data
    else:
        intake_history_data = intake_history_doc.to_dict()
    
    period_data = intake_history_data.get(period, {})
    
    # Add this check to handle boolean values
    if isinstance(period_data, bool):
        period_data = {
            "taken": period_data,
            "notification_sent": False,
            "missed_notification_sent": False
        }
        # Save the updated structure back to the database
        intake_history_doc_ref.update({ period: period_data })
    
    taken = period_data.get("taken", False)
    missed_notification_sent = period_data.get("missed_notification_sent", False)
    
    # Calculate the missed dose threshold time in user's timezone
    grace_period = timedelta(minutes=NOTIFICATION_WINDOW_MINUTES)
    missed_time = due_time + grace_period
    current_time_user_tz = datetime.now(user_tz)
    
    if not taken and not missed_notification_sent and current_time_user_tz > missed_time:
        # Send missed dose notification
        user_doc = user.reference.get()
        if user_doc.exists:
            user_data = user_doc.to_dict()
            fcm_token = user_data.get("fcm_token")
            settings = user_data.get("notification_settings", {})
            
            if settings.get("missed_dose_alerts", True) and fcm_token:
                send_fcm_notification(
                    fcm_token,
                    f"Missed {period.capitalize()} Dose",
                    "You missed your medication dose!"
                )
                # Update intake history to mark missed notification as sent
                update_data = {f"{period}.missed_notification_sent": True}
                intake_history_doc_ref.update(update_data)

# Firebase Cloud Messaging (FCM) Notification Handler
def send_fcm_notification(fcm_token: str, title: str, body: str):
    try:
        if not fcm_token:
            logger.warning("No FCM token available for user")
            return

        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body
            ),
            token=fcm_token
        )
        
        response = messaging.send(message)
        logger.info(f"Successfully sent FCM notification: {response}")
        return response
        
    except Exception as e:
        logger.error(f"Failed to send FCM notification: {str(e)}", exc_info=True)
        raise

class IntakeUpdate(BaseModel):
    email: str
    date: str  # Expected format: YYYY-MM-DD
    period: str  # Must be 'morning', 'afternoon', or 'night'

@app.post("/db/update-intake")
async def update_intake(update: IntakeUpdate):
    # Validate period
    allowed_periods = ["morning", "afternoon", "night"]
    if update.period not in allowed_periods:
        raise HTTPException(status_code=400, 
                            detail="Invalid period. Must be morning, afternoon, or night.")
    
    # Validate date format
    try:
        parsed_date = datetime.fromisoformat(update.date).strftime("%Y-%m-%d")
    except ValueError:
        raise HTTPException(status_code=400, 
                            detail="Invalid date format. Use ISO format (YYYY-MM-DD).")
    
    # Check if user exists
    user_ref = db.collection("USER").document(update.email)
    user = user_ref.get()
    if not user.exists:
        raise HTTPException(status_code=404, detail="User not found.")
    
    # Reference intake history document
    intake_history_ref = user_ref.collection("intake_history").document(parsed_date)
    
    # Check if the intake history document exists
    history_doc = intake_history_ref.get()
    if not history_doc.exists():
        # Initialize with all periods as False
        intake_history_ref.set({
            "morning": False,
            "afternoon": False,
            "night": False
        })
    
    # Update the specified period
    try:
        intake_history_ref.update({
            update.period: True
        })
        return {"status": "success", 
                "message": f"{update.period} intake updated for {update.email} on {parsed_date}"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to update intake history: {str(e)}")

@app.post("/user/register-token", status_code=200)
async def register_token(email: str, token: str, ):
    user_ref = db.collection("USER").document(email)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    user_ref.update({"fcm_token": token})
    return {"status": "Token registered successfully"}

@app.get("/update-notifications", status_code=200)
async def update_notifications(email: str):
    # Verify user exists
    user_ref = db.collection("USER").document(email)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    user_data = user_doc.to_dict()
    user_tz = get_user_timezone(user_data)
    today = datetime.now(user_tz).date().isoformat()
    
    # Initialize notifications dictionary (will only include untaken medications)
    notifications = {}
    
    # Get intake history for today
    intake_history_ref = user_ref.collection("intake_history").document(today)
    intake_history_doc = intake_history_ref.get()
    
    if not intake_history_doc.exists:
        default_history = {
            p: {"taken": False, "notification_sent": False, "missed_notification_sent": False}
            for p in ["morning", "afternoon", "night"]
        }
        intake_history_ref.set(default_history)
        intake_history_data = default_history
    else:
        intake_history_data = intake_history_doc.to_dict()
    
    # Get prescription details and time windows
    prescription_ref = user_ref.collection("prescriptions").document("defaultPrescription")
    pres_doc = prescription_ref.get()
    time_windows = get_user_time_windows(email)
    
    if pres_doc.exists:
        prescriptions = pres_doc.to_dict()
        
        # Process each prescription (slot)
        for slot_number, prescription in prescriptions.items():
            if isinstance(prescription, dict):
                frequency = prescription.get("frequency", {})
                
                # Check which periods this medication is prescribed for
                for period in ["morning", "afternoon", "night"]:
                    # Get intake status
                    period_data = intake_history_data.get(period, {})
                    taken = period_data.get("taken", False) if isinstance(period_data, dict) else period_data
                    
                    # Skip if medication is already taken
                    if taken:
                        continue
                        
                    # Only process if medication is scheduled for this period
                    if frequency.get(period, False):
                        window = time_windows.get(period, {"hour": 0, "minute": 0})
                        take_time = f"{window['hour']:02d}:{window['minute']:02d}"
                        
                        # Initialize period in notifications if not exists
                        if period not in notifications:
                            notifications[period] = {
                                "tabletName": "",
                                "takeTime": take_time,
                                "takeDuration": "",
                                "taken": False,
                                "missed": False,
                                "afterFood": True,
                                "dosage": 0.0
                            }
                        
                        # Update or append medication details
                        current_tablets = notifications[period]["tabletName"]
                        new_tablet = prescription.get("tabletName", "")
                        
                        notifications[period].update({
                            "tabletName": f"{current_tablets}, {new_tablet}".strip(", "),
                            "takeTime": take_time,
                            "takeDuration": str(prescription.get("duration", "")),
                            "afterFood": not prescription.get("beforeFood", True),
                            "dosage": float(prescription.get("dosage", 0))
                        })
    
    return {"notifications": notifications}

@app.get("/user/time", status_code=200)
async def get_user_settings(email: str):
    # Verify user exists
    user_ref = db.collection("USER").document(email)
    user_doc = user_ref.get()
    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Get settings document
    settings_ref = user_ref.collection("settings").document("defaultSettings")
    settings_doc = settings_ref.get()
    
    if not settings_doc.exists:
        raise HTTPException(status_code=404, detail="Settings not found")
    
    settings_data = settings_doc.to_dict()
    print("settings_data", settings_data)
    # Extract and format timing settings
    response = {
        "timings": {
            "morning": {
                "hour": settings_data.get("morning", {}).get("hour", 9),
                "minute": settings_data.get("morning", {}).get("minute", 25)
            },
            "afternoon": {
                "hour": settings_data.get("afternoon", {}).get("hour", 13),
                "minute": settings_data.get("afternoon", {}).get("minute", 30)
            },
            "night": {
                "hour": settings_data.get("night", {}).get("hour", 21),
                "minute": settings_data.get("night", {}).get("minute", 30)
            }
        },
    }
    
    return response

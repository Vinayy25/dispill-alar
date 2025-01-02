from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
import firebase_admin
from firebase_admin import firestore, credentials
from typing import List, Dict, Optional
from datetime import datetime
from fastapi.responses import JSONResponse

# Initialize Firebase Admin SDK
cred = credentials.Certificate("firebaseKeys.json")
firebase_admin.initialize_app(cred)  # Initialize app with credentials

# Firestore client
db = firestore.client()  # No need to pass cred here, as initialize_app() already handles it

app = FastAPI()

# Pydantic models for input data validation
class Frequency(BaseModel):
    morning: Optional[bool] = None
    afternoon: Optional[bool] = None
    night: Optional[bool] = None

class SlotDetails(BaseModel):
    frequency: Frequency
    tabletName: str

class TimePeriod(BaseModel):
    hour: int
    minute: int


# Helper function to fetch time periods from Firestore
async def fetch_time_periods(email: str, settings_doc) -> Dict[str, int]:


    if not settings_doc.exists:
        raise HTTPException(status_code=404, detail="Default settings not found")

    default_settings = settings_doc.to_dict()

    time_periods = {
        "morning": (default_settings.get("morning", {}).get("hour", 8) * 60 + default_settings.get("morning", {}).get("minute", 0)),
        "afternoon": (default_settings.get("afternoon", {}).get("hour", 14) * 60 + default_settings.get("afternoon", {}).get("minute", 0)),
        "night": (default_settings.get("night", {}).get("hour", 20) * 60 + default_settings.get("night", {}).get("minute", 0)),
    }
    return time_periods

@app.get("/healthcheck")
async def health_check():
    return {"status": "Healthy"}

@app.get("/update-notifications")
async def get_remaining_medications(email: str  ):
    response = {}
    try:
        # Fetch time periods for the user
        current_time = datetime.utcnow()  # Use UTC time as current time
        current_minutes = current_time.hour * 60 + current_time.minute

        # Fetch prescription data
        prescription_ref = db.collection("USER").document(email).collection("prescriptions").document("defaultPrescription")
        settings_ref = db.collection("USER").document(email).collection("settings").document("defaultSettings")
        today = current_time.date().isoformat()  # Get today's date in ISO format
        intake_history_ref = db.collection("USER").document(email).collection("intake_history").document(today)
        intake_history_doc = intake_history_ref.get()
        settings_doc = settings_ref.get()
        prescription_doc = prescription_ref.get()


        print("prescription doc", prescription_doc.to_dict())
        
        time_periods = await fetch_time_periods(email, settings_doc)

        
        if not prescription_doc.exists:
            raise HTTPException(status_code=404, detail="Prescription not found")

        prescription_data = prescription_doc.to_dict()
        print("prescription data", prescription_data)
        if not intake_history_doc.exists:
            intake_history_ref.set({
                "morning": False,
                "afternoon": False,
                "night": False
            })
            intake_history = {"morning": False, "afternoon": False, "night": False}
        else:
            intake_history = intake_history_doc.to_dict()

        remaining_medications: List[str] = []
        
# Check each slot in the prescription
        for slot, details in prescription_data.items():
            print(details)
            if details['everyday'] == True:
                frequency, tablet_name = details["frequency"], details["tabletName"]
                print("frequency", frequency)

                for period, is_required in frequency.items():
                    if is_required:
                        period_time = time_periods.get(period)
                        if period_time is not None:
                            already_taken = intake_history[period]
                            print ("already taken " , already_taken)
                            if  already_taken is False or (period_time > current_minutes):
                                remaining_medications.append(f"{details['tabletName']} ({period})")
                                period_in_hours = str(period_time // 60) + ':' + str(period_time % 60)
                                response[slot] = ({"tabletName": details['tabletName'],
                                                 "takeDuration": period,
                                                    "takeTime": period_in_hours,
                                                    "missed":False,
                                                    "afterFood": details.get('afterFood', False),
                                                    "slotNumber": slot,
                                                    "dosage": details.get('dosage', 1),
                                                 } )
                            elif period_time < current_minutes and already_taken is False:
                                response[slot] = ({"tabletName": details['tabletName'],
                                                    "takeDuration": period,
                                                        "takeTime": period_time,
                                                        "missed":True,
                                                        "afterFood": details.get('afterFood', False),
                                                        "slotNumber": slot,
                                                        "dosage": details.get('dosage', 1),
                                                    } )
                                print("missed the medication" , details['tabletName'])
                        else:
                            print(f"Warning: Undefined period: {period} in timePeriods")
                        
            else:
                # Check if certainDays exists and process accordingly
                frequency, tablet_name = details["frequency"], details["tabletName"]
                certain_days = details.get('certainDays', {})
                for period, is_required in frequency.items():
                    # Ensure `is_required` is True and the current day is marked as True in certainDays
                    current_day = current_time.strftime("%A").lower()
                    if is_required and certain_days.get(current_day, "False") == True:
                        period_time = time_periods.get(period)
                        if period_time is not None:
                            already_taken = intake_history[period]
                            if  already_taken is False or (period_time > current_minutes):
                                remaining_medications.append(f"{details['tabletName']} ({period})")
                                response[slot]= ({"tabletName": details['tabletName'],
                                                 "takeDuration": period,
                                                    "takeTime": period_time,
                                                    "missed":False,
                                                    "slotNumber": slot,
                                                    "afterFood": details.get('afterFood', False),
                                                    "dosage": details.get('dosage', 1),
                                                 } )
                            elif period_time < current_minutes and already_taken is False:
                                response[slot] = ({"tabletName": details['tabletName'],
                                                    "takeDuration": period,
                                                    "slotNumber": slot,
                                                        "takeTime": period_time,
                                                        "missed":True,
                                                        "afterFood": details.get('afterFood', False),
                                                        "dosage": details.get('dosage', 1),
                                                    } )
                                print("missed the medication" , details['tabletName'])
                        else:
                            print(f"Warning: Undefined period: {period} in timePeriods")


        if remaining_medications:
            print(response)


            return JSONResponse(content={"notifications": response})   
            return {"message": "Remaining medications for today:", "medications": remaining_medications}
        
        else:
            return {"message": "No remaining medications for today."}

    except Exception as error:
        print("Error fetching remaining medications:", error)
        raise HTTPException(status_code=500, detail="Internal Server Error")

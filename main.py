from fastapi import FastAPI, BackgroundTasks, HTTPException
import json
from contextlib import asynccontextmanager
import paho.mqtt.client as mqtt
from google.cloud import firestore

db = firestore.Client.from_service_account_json("firebaseKeys.json")

@asynccontextmanager
async def lifespan(app: FastAPI):
    # MQTT client setup
    mqtt_client = mqtt.Client()
    MQTT_BROKER = "mqtt.example.com"  # Replace with your MQTT broker URL or IP
    MQTT_PORT = 1883

    mqtt_client.connect(MQTT_BROKER, MQTT_PORT)
    mqtt_client.loop_start()
    print("MQTT connected.")

    app.state.mqtt_client = mqtt_client

    yield

    mqtt_client.loop_stop()
    mqtt_client.disconnect()
    print("MQTT disconnected.")

app = FastAPI(lifespan=lifespan)

# Publish function to send data to a device
def publish_to_device(mqtt_client, user_email: str, device_data: dict):
    topic = f"pill_dispenser/{user_email}/update"
    mqtt_client.publish(topic, json.dumps(device_data))
    print(f"Published to {topic}: {device_data}")

# Helper to parse Firestore structure and format data for ESP32
def parse_prescription_data(data: dict):
    parsed_data = []
    prescriptions = data.get("prescriptions", {}).get("defaultPrescription", {})

    for slot, details in prescriptions.items():
        parsed_data.append({
            "slotNumber": slot,
            "tabletName": details.get("tabletName", ""),
            "beforeFood": details.get("beforeFood", False),
            "everyday": details.get("everyday", False),
            "frequency": details.get("frequency", {}),
            "certainDays": details.get("certainDays", {}),
            "dosage": details.get("dosage", 0),
            "instructions": details.get("instructions", []),
            "notes": details.get("notes", []),
        })

    return parsed_data

# HTTP endpoint to handle Firestore change notification
@app.post("/firebase_update")
async def handle_firebase_update(payload: dict, background_tasks: BackgroundTasks):
    try:
        user_email = payload.get("user_email")
        if not user_email:
            raise HTTPException(status_code=400, detail="user_email is required")

        data = payload.get("data")
        if not data:
            raise HTTPException(status_code=400, detail="data is required")

        # Parse and format data for the ESP32
        formatted_data = parse_prescription_data(data)

        # Update ESP32 via MQTT in the background
        background_tasks.add_task(publish_to_device, app.state.mqtt_client, user_email, formatted_data)

        return {"status": "Update triggered", "user_email": user_email}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))



def fetch_timings_from_firestore(user_email: str):
    try:
        # Reference to the defaultSettings document inside the user's settings collection
        doc_ref = db.collection('USER').document(user_email).collection('settings').document('defaultSettings')
        doc = doc_ref.get()

        if not doc.exists:
            print(f"No defaultSettings found for user: {user_email}")
            return None

        # Extract data from the document
        settings = doc.to_dict()
        if not settings:
            print(f"No data found in defaultSettings for user: {user_email}")
            return None

        # Format the timing data
        timings = {
            "morning": {
                "hour": settings.get("morning", {}).get("hour", 0),
                "minute": settings.get("morning", {}).get("minute", 0),
            },
            "afternoon": {
                "hour": settings.get("afternoon", {}).get("hour", 0),
                "minute": settings.get("afternoon", {}).get("minute", 0),
            },
            "night": {
                "hour": settings.get("night", {}).get("hour", 0),
                "minute": settings.get("night", {}).get("minute", 0),
            },
            "showNotifications": settings.get("showNotifications", True),
            "snoozeLength": settings.get("snoozeLength", 5),
            "sound": settings.get("sound", "Default"),
            "vibrate": settings.get("vibrate", False),
            "whiteTheme": settings.get("whiteTheme", False),
        }

        print(f"Timings fetched for user: {user_email}: {timings}")
        return timings

    except Exception as e:
        print(f"Error fetching timings: {e}")
        return None

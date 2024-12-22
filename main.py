from fastapi import FastAPI, BackgroundTasks, HTTPException
import paho.mqtt.client as mqtt
import json

app = FastAPI()

# MQTT client setup
mqtt_client = mqtt.Client()
MQTT_BROKER = "mqtt.example.com"  # Replace with your MQTT broker URL or IP
MQTT_PORT = 1883

mqtt_client.connect(MQTT_BROKER, MQTT_PORT)
mqtt_client.loop_start()

# Publish function to send data to a device
def publish_to_device(user_email: str, device_data: dict):
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
        background_tasks.add_task(publish_to_device, user_email, formatted_data)

        return {"status": "Update triggered", "user_email": user_email}

    except Exception as e:
        print(f"Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Lifespan context manager for app lifecycle
from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    yield  # App runs here
    mqtt_client.loop_stop()
    mqtt_client.disconnect()
    print("MQTT disconnected.")

app = FastAPI(lifespan=lifespan)

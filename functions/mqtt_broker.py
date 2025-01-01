import paho.mqtt.client as mqtt
import json
from datetime import datetime
from firebase_service import log_tablet_intake
import os
from dotenv import load_dotenv
load_dotenv()


# MQTT broker details
BROKER = os.getenv("BROKER")
PORT = int(os.getenv("PORT"))
USERNAME = os.getenv("USERNAME")
PASSWORD = os.getenv("PASSWORD")
TOPIC = os.getenv("TOPIC")

# Callback when a message is received
def on_message( client, userdata, msg):
    try:
        # Decode and parse the JSON message
        payload = msg.payload.decode("utf-8")
        data = json.loads(payload)
        ## Example message:
        # {
        #     "message_context": "tablet_intake_update",
        #     "email": "
        #     "timestamp": "2021-09-01T08:00:00Z",
        #     "taken": true,
        #     "notes": "Taken with breakfast"
        # }
        # Log the received message
        print(f"Received message on topic {msg.topic}: {data}")
        # Process based on the `message_context`
        message_context = data.get("message_context", "unknown")
        email = data.get("email", "unknown")
        if message_context == "tablet_intake_update":
            print("Processing tablet intake update...")

            # Extract timestamp and taken status
            timestamp = data.get("timestamp", "unknown")
            taken = data.get("taken", False)
            # Convert and log timestamp
            try:
                message_time = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
                print(f"Message timestamp: {message_time}")
            except Exception as e:
                print(f"Invalid timestamp format: {timestamp}. Error: {e}")
                return
            # Check if tablet was taken
            if taken:
                print("✅ Tablet has been taken.")
            else:
                print("❌ Tablet has NOT been taken.")
            # Log additional notes if present
            if "notes" in data:
                print(f"Notes: {data['notes']}")
            # Determine the period based on the timestamp (e.g., morning/afternoon/evening)
            hour = datetime.fromisoformat(timestamp.replace("Z", "+00:00")).hour
            if 5 <= hour < 12:
                period = "morning"
            elif 12 <= hour < 17:
                period = "afternoon"
            elif 17 <= hour < 22:
                period = "evening"
            else:
                print("Skipping logging for nighttime hours.")
                return

            log_tablet_intake(email, timestamp, period, taken)
        else:
            print(f"Unknown message context: {message_context}")

    except json.JSONDecodeError:
        print("Error: Received a non-JSON message.")
    except Exception as e:
        print(f"Error processing message: {e}")

# Callback when the client connects to the broker
def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected successfully to the broker!")
        client.subscribe(TOPIC)
        print(f"Subscribed to topic: {TOPIC}")
    else:
        print(f"Failed to connect, return code {rc}")

# Create the MQTT client
client = mqtt.Client()

# Set username and password for the broker
client.username_pw_set(USERNAME, PASSWORD)

# Enable TLS for secure connection
client.tls_set("/etc/ssl/certs/ca-certificates.crt")

# Assign callbacks
client.on_connect = on_connect
client.on_message = on_message

# Connect to the broker
print("Connecting to the broker...")
client.connect(BROKER, PORT)

# Start the network loop
client.loop_forever()

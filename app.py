from fastapi import FastAPI
from apscheduler.schedulers.background import BackgroundScheduler
from pyfcm import FCMNotification
import datetime

import os
app = FastAPI()

# Initialize Firebase FCM
fcm = FCMNotification(service_account_file="./firebaseKeys.json", project_id="dispill-alar", )


# Initialize the scheduler
scheduler = BackgroundScheduler()
scheduler.start()

# Function to send FCM notification
def send_fcm_notification(title: str, body: str, token: str):
    message = {
        "title": title,
        "body": body
    }
    fcm.notify_single_device(registration_id=token, message_title=title, message_body=body)

# Route to schedule a notification
@app.post("/schedule-notification/")
async def schedule_notification(title: str, body: str, token: str, delay_in_seconds: int):
    schedule_time = datetime.datetime.now() + datetime.timedelta(seconds=delay_in_seconds)
    scheduler.add_job(send_fcm_notification, 'date', run_date=schedule_time, args=[title, body, token])
    return {"message": f"Notification scheduled at {schedule_time}"}




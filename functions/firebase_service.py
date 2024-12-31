import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase Admin SDK
cred = credentials.Certificate("firebase-key.json")  # Path to your Firebase credentials JSON file
firebase_admin.initialize_app(cred)

# Initialize Firestore
db = firestore.client()



def log_tablet_intake(email,timestamp, period, taken):
    """
    Logs tablet intake to Firebase Firestore.

    Args:
        timestamp (str): ISO8601 formatted timestamp.
        period (str): One of 'morning', 'afternoon', 'evening'.
        taken (bool): True if the tablet was taken, False otherwise.
    """
    try:
        # Parse the date from the timestamp
        date = datetime.fromisoformat(timestamp.replace("Z", "+00:00")).strftime("%Y-%m-%d")
        
        # Reference to the Firestore collection
        collection_ref = db.collection('USER').document(email).collection('intake_history')
        
        # Reference to the specific document for the date
        doc_ref = collection_ref.document(date)
        
        # Update the document with the given period
        doc_ref.set({period: taken}, merge=True)  # Merge ensures only the specific period is updated
        
        print(f"Successfully logged {period} tablet intake for {date}: {taken}")
    except Exception as e:
        print(f"Error logging tablet intake: {e}")

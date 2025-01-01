import * as admin from "firebase-admin";
import * as functions from "firebase-functions";

admin.initializeApp();

const db = admin.firestore();

// Define types for Firestore data
interface Frequency {
  morning?: boolean;
  afternoon?: boolean;
  night?: boolean;
}

interface SlotDetails {
  frequency: Frequency;
  tabletName: string;
}
// Define time period type
interface TimePeriod {
  hour: number;
  minute: number;
}

// Fetch time periods from Firestore
const fetchTimePeriods = async (userId: string): Promise<{ [key in keyof Frequency]: number }> => {
  const settingsDoc = await db
    .collection("USER")
    .doc(userId)
    .collection("settings")
    .doc("defaultSettings")
    .get();

  if (!settingsDoc.exists) {
    throw new Error("Default settings not found");
  }

  const defaultSettings = settingsDoc.data() as {
    morning?: TimePeriod;
    afternoon?: TimePeriod;
    night?: TimePeriod;
  };

  // Convert hour and minute to minutes since midnight
  const timePeriods: { [key in keyof Frequency]: number } = {
    morning: defaultSettings.morning ? defaultSettings.morning.hour * 60 + defaultSettings.morning.minute : 8 * 60,
    afternoon: defaultSettings.afternoon ? defaultSettings.afternoon.hour * 60 + defaultSettings.afternoon.minute : 14 * 60,
    night: defaultSettings.night ? defaultSettings.night.hour * 60 + defaultSettings.night.minute : 20 * 60,
  };

  return timePeriods;
};

export const getRemainingMedications = functions.https.onRequest(
  async (req, res) => {
    try {
      const userId = req.query.userId as string;

      if (!userId) {
        res.status(400).send("Missing userId parameter");
        return;
      }
        const timePeriods = await fetchTimePeriods(userId);
      // Fetch user's defaultPrescription data
      const prescriptionDoc = await db
        .collection("USER")
        .doc(userId)
        .collection("prescriptions")
        .doc("defaultPrescription")
        .get();

      if (!prescriptionDoc.exists) {
        res.status(404).send("Prescription not found");
        return;
      }

      const prescriptionData = prescriptionDoc.data() as {
        [slot: string]: SlotDetails;
      };

      // Current date and time
      const now = new Date();
      const today = now.toISOString().split("T")[0];
      const currentTime = now.getHours() * 60 + now.getMinutes();

      // Fetch intake history for today's date
      const intakeHistoryDoc = await db
        .collection("USER")
        .doc(userId)
        .collection("intake_history")
        .doc(today)
        .get();

      const intakeHistory = intakeHistoryDoc.exists
        ? intakeHistoryDoc.data() || {}
        : {};

      const remainingMedications: string[] = [];

      // Check each slot in the prescription
      for (const [slot, details] of Object.entries(prescriptionData)) {
        const { frequency, tabletName } = details;

        for (const [period, isRequired] of Object.entries(frequency)) {
          if (isRequired) {
            const periodTime = timePeriods[period as keyof Frequency]; // Add type assertion

            // Ensure periodTime is defined
            if (periodTime !== undefined) {
              const alreadyTaken = intakeHistory[period] || false;

              if (!alreadyTaken && periodTime > currentTime) {
                remainingMedications.push(`${tabletName} (${period})`);
              }
            } else {
              console.warn(`Undefined period: ${period} in timePeriods`);
            }
          }
        }
      }

      if (remainingMedications.length > 0) {
        res.status(200).send({
          message: "Remaining medications for today:",
          medications: remainingMedications,
        });
      } else {
        res.status(200).send({
          message: "No remaining medications for today.",
        });
      }
    } catch (error) {
      console.error("Error fetching remaining medications:", error);
      res.status(500).send("Internal Server Error");
    }
  }
);

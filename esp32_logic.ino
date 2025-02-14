#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <LittleFS.h>
#include <RTClib.h>

RTC_DS3231 rtc;

// WiFi and MQTT Configuration
const char *ssid = "YOUR_SSID";
const char *password = "YOUR_PASSWORD";
const char *mqttServer = "mqtt.broker.com";
const int mqttPort = 1883;
const char *mqttUser = "user";
const char *mqttPassword = "password";

WiFiClient espClient;
PubSubClient mqttClient(espClient);

// Hardware Configuration
const int touchPins[] = {13, 12, 14, 27, 26, 25}; // TTP223 touch sensors
const int ledPins[] = {5, 18, 19, 21, 22, 23};    // LEDs
const int buzzerPin = 4;                          // Buzzer

// Data Structures
struct TimeSlot
{
    int hour;
    int minute;
    bool takenToday;
};

struct Compartment
{
    int number;
    String tabletName;
    TimeSlot times[5]; // Max 5 times per compartment
    int timeCount;
};

Compartment compartments[6];
int lastCheckedDay = -1;
bool buzzerActive = false;

// MQTT Topics
const char *statusTopic = "pill_dispenser/status";
const char *updateTopic = "pill_dispenser/update";

void setup()
{
    Serial.begin(115200);

    // Initialize hardware
    initializeHardware();
    initializeRTC();
    initializeFilesystem();
    connectWiFi();
    initializeMQTT();
}

void loop()
{
    DateTime now = rtc.now();

    // Daily reset
    handleDayChange(now);

    // Core functionality
    checkSchedule(now);
    handleTouchInput(now);
    handleMQTT();
    checkMissedPills(now);

    // Periodic tasks
    static unsigned long lastUpdate = 0;
    if (millis() - lastUpdate > 5000)
    {
        lastUpdate = millis();
        checkForUpdates();
    }

    delay(100);
}

// Initialization functions
void initializeHardware()
{
    for (int i = 0; i < 6; i++)
    {
        pinMode(touchPins[i], INPUT);
        pinMode(ledPins[i], OUTPUT);
        digitalWrite(ledPins[i], LOW);
    }
    pinMode(buzzerPin, OUTPUT);
    digitalWrite(buzzerPin, LOW);
}

void initializeRTC()
{
    if (!rtc.begin())
    {
        Serial.println("RTC initialization failed!");
        while (1)
            ;
    }
    if (rtc.lostPower())
        rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));
}

void initializeFilesystem()
{
    if (!LittleFS.begin())
    {
        Serial.println("LittleFS mount failed!");
        return;
    }
    loadSchedule();
}

// Schedule management
void loadSchedule()
{
    File file = LittleFS.open("/schedule.json", "r");
    if (!file)
    {
        Serial.println("Failed to open schedule file");
        return;
    }

    DynamicJsonDocument doc(1024);
    DeserializationError error = deserializeJson(doc, file);
    if (error)
    {
        Serial.println("Failed to parse schedule file");
        file.close();
        return;
    }

    // Parse JSON and populate compartments array
    // (Implementation similar to previous example)
}

// WiFi and MQTT functions
void connectWiFi()
{
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED)
        delay(500);
    Serial.println("WiFi connected");
}

void initializeMQTT()
{
    mqttClient.setServer(mqttServer, mqttPort);
    mqttClient.setCallback(mqttCallback);
    reconnectMQTT();
}

// Core logic functions
void checkSchedule(DateTime now)
{
    bool anyActive = false;

    for (int i = 0; i < 6; i++)
    {
        bool active = false;
        for (int j = 0; j < compartments[i].timeCount; j++)
        {
            if (isTimeActive(now, compartments[i].times[j]))
            {
                active = true;
                break;
            }
        }
        digitalWrite(ledPins[i], active ? HIGH : LOW);
        anyActive |= active;
    }

    digitalWrite(buzzerPin, anyActive ? HIGH : LOW);
}

void handleTouchInput(DateTime now)
{
    for (int i = 0; i < 6; i++)
    {
        if (digitalRead(touchPins[i]) == HIGH)
        {
            handleCompartmentPress(i, now);
            delay(200); // Debounce
        }
    }
}

// Helper functions
bool isTimeActive(DateTime now, TimeSlot slot)
{
    if (slot.takenToday)
        return false;

    int scheduled = slot.hour * 60 + slot.minute;
    int current = now.hour() * 60 + now.minute();
    int diff = abs(current - scheduled);
    if (diff > 720)
        diff = 1440 - diff;

    return diff <= 5;
}

void handleCompartmentPress(int index, DateTime now)
{
    bool activated = false;

    for (int j = 0; j < compartments[index].timeCount; j++)
    {
        TimeSlot &slot = compartments[index].times[j];
        if (isTimeActive(now, slot))
        {
            slot.takenToday = true;
            activated = true;
            sendStatusUpdate(index, "taken", now);
        }
    }

    if (activated)
    {
        digitalWrite(ledPins[index], LOW);
        checkBuzzerState();
    }
}

// MQTT functions
void sendStatusUpdate(int index, const char *status, DateTime timestamp)
{
    char isoTime[25];
    sprintf(isoTime, "%04d-%02d-%02dT%02d:%02d:%02d",
            timestamp.year(), timestamp.month(), timestamp.day(),
            timestamp.hour(), timestamp.minute(), timestamp.second());

    DynamicJsonDocument doc(256);
    doc["compartment"] = compartments[index].number;
    doc["tablet_name"] = compartments[index].tabletName;
    doc["status"] = status;
    doc["timestamp"] = isoTime;

    char buffer[256];
    serializeJson(doc, buffer);
    mqttClient.publish(statusTopic, buffer);
}

// Additional features
void checkMissedPills(DateTime now)
{
    // Implementation for missed pill tracking
}

void checkForUpdates()
{
    // Implementation for schedule updates
}

void handleDayChange(DateTime now)
{
    if (now.day() != lastCheckedDay)
    {
        resetDailyStates();
        lastCheckedDay = now.day();
    }
}

void resetDailyStates()
{
    for (int i = 0; i < 6; i++)
    {
        for (int j = 0; j < compartments[i].timeCount; j++)
        {
            compartments[i].times[j].takenToday = false;
        }
    }
}

void checkBuzzerState()
{
    bool active = false;
    for (int i = 0; i < 6; i++)
    {
        if (digitalRead(ledPins[i]) == HIGH)
        {
            active = true;
            break;
        }
    }
    digitalWrite(buzzerPin, active ? HIGH : LOW);
}
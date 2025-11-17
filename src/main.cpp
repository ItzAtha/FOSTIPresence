// ===========================[ ESP32 WiFi ]===========================
// Import package for ESP32 System
#include <WiFi.h>
#include <WiFiClientSecure.h>

// Create instance of wifi client secure
// This client is used for secure connections (HTTPS)
WiFiClientSecure client;
// ====================================================================

// ==========================[ RFID Reader ]===========================
// Import package for RFID System
#include <MFRC522.h>
#include <SPI.h>

// Initial SS and RST pin of MFRC522 (RFID)
#define SS_PIN 5
#define RST_PIN 21

// Create instance of MFRC522 (RFID)
MFRC522 rfid(SS_PIN, RST_PIN);
// ====================================================================

// ========================[ System Databases ]========================
// Import package for PostmanAPI Supabase Database (External)
#include <APIManager.h>

// Import package for Preferences Database (Local)
#include <Preferences.h>

// Initialize PostmanAPI URL Server
String apiUrl = "https://fostipresensiapi.vercel.app";

// Create instance of PostmanAPI Supabase Database
PostmanAPI api(client, apiUrl);

// Create instance of LittleFS Database
Preferences pref;
// ====================================================================

// ======================[ OLED 128x64 0.96 Inch ]=====================
// Import package for OLED 128x64
#include <Adafruit_SSD1306.h>
#include <Wire.h>

// Import the OLED text fonts style
#include <Fonts/FreeSansBold6pt7b.h>
#include <Fonts/FreeSansBold7pt7b.h>

// Initial the OLED screen size
#define OLED_SCREEN_WIDTH 128
#define OLED_SCREEN_HEIGHT 64
#define OLED_RESET -1
#define OLED_SCREEN_ADDRESS 0x3C

// Create instance of OLED 128x64
Adafruit_SSD1306 display(OLED_SCREEN_WIDTH, OLED_SCREEN_HEIGHT, &Wire,
                         OLED_RESET);
// ====================================================================

// ===========================[ NTP CLIENT ]===========================
// Import package for NTP Client
#include <NTPClient.h>
#include <WiFiUdp.h>

// Create instance of WiFi UDP for NTP Client
WiFiUDP ntpUDP;

// NTP Server Credentials
const char *serverName = "pool.ntp.org";
int timezoneGMT = 7;
unsigned long updateInterval = 60000;

// Create instance of NTP Client
NTPClient ntpClient(ntpUDP, serverName, timezoneGMT * 3600, updateInterval);
// ====================================================================

// =========================[ Debug Settings ]==========================
#define DEBUG_ALL true

// Define the HardwareSerial object for the chosen UART
HardwareSerial ReceiverPort(1);    // Using UART1
HardwareSerial TransmitterPort(2); // Using UART2

// Enum for System Options
enum MainMenuOption { MAIN_MENU, REGISTER, ATTENDANCE };
enum PresenceOption { NONE, PARTICIPANT, COMMITTEE, BPHI };

// ========================[ Task Handlers ]===========================
TaskHandle_t taskMainHandler;
TaskHandle_t taskRegisterHandler;
TaskHandle_t taskAttendanceHandler;

TaskHandle_t taskLoadingHandler;
TaskHandle_t taskCheckConnectionHandler;

// ========================[ Global Variables ]========================
MainMenuOption mainMenuOption =
    MainMenuOption::MAIN_MENU; // Current main menu option
PresenceOption presenceOption =
    PresenceOption::NONE; // Current attendance option

// Settings variables initialization
String receivedData = "";
String currentEvent = "";  // Current event for attendance
bool showDivision = false; // Flag to show division in attendance

// WiFi & others variables initialization
int MAX_WIFI_RETRIES = 32;   // Max retries for WiFi connection
int currentWiFiDot = -1;     // Current dot for WiFi connection
bool isDisconnected = false; // Flag to check if WiFi is disconnected

// 'user_white', 50x60px
// This icon is used to represent the user
const unsigned char userBitmap[] PROGMEM = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x3f, 0xf0, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xff, 0xfc, 0x00, 0x00, 0x00, 0x00, 0x03, 0xff, 0xfe, 0x00, 0x00,
    0x00, 0x00, 0x07, 0xff, 0xff, 0x00, 0x00, 0x00, 0x00, 0x0f, 0xff, 0xff,
    0xe0, 0x00, 0x00, 0x00, 0x0f, 0xff, 0xff, 0xf0, 0x00, 0x00, 0x00, 0x1f,
    0xff, 0xff, 0xf8, 0x00, 0x00, 0x00, 0x1f, 0xff, 0xff, 0xf8, 0x00, 0x00,
    0x00, 0x3f, 0xff, 0xfc, 0xf8, 0x00, 0x00, 0x00, 0x3f, 0xff, 0xf8, 0xf8,
    0x00, 0x00, 0x00, 0x3f, 0xff, 0xe0, 0xf8, 0x00, 0x00, 0x00, 0x3f, 0xff,
    0x81, 0xf8, 0x00, 0x00, 0x00, 0x0f, 0xf0, 0x01, 0xf8, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0xf8, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x38, 0x00, 0x00, 0x00, 0x06, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x07,
    0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x38, 0x00, 0x00,
    0x00, 0x07, 0x00, 0x00, 0x38, 0x00, 0x00, 0x00, 0x07, 0x00, 0x00, 0x38,
    0x00, 0x00, 0x00, 0x07, 0x80, 0x00, 0x78, 0x00, 0x00, 0x00, 0x03, 0x80,
    0x00, 0xf0, 0x00, 0x00, 0x00, 0x03, 0xc0, 0x00, 0xf0, 0x00, 0x00, 0x00,
    0x01, 0xe0, 0x03, 0xe0, 0x00, 0x00, 0x00, 0x00, 0xf8, 0x07, 0xc0, 0x00,
    0x00, 0x00, 0x00, 0x7f, 0x3f, 0x80, 0x00, 0x00, 0x00, 0x00, 0x3f, 0xff,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0xfc, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x07, 0xfc, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x7f, 0xff, 0x80, 0x00, 0x00, 0x00, 0x01, 0xff,
    0xff, 0xe0, 0x00, 0x00, 0x00, 0x07, 0xf0, 0x03, 0xf8, 0x00, 0x00, 0x00,
    0x1f, 0x80, 0x00, 0x7e, 0x00, 0x00, 0x00, 0x3e, 0x00, 0x00, 0x1f, 0x00,
    0x00, 0x00, 0x7c, 0x00, 0x00, 0x0f, 0x80, 0x00, 0x00, 0xf8, 0x00, 0x00,
    0x07, 0xc0, 0x00, 0x00, 0xf0, 0x00, 0x00, 0x03, 0xe0, 0x00, 0x01, 0xe0,
    0x00, 0x00, 0x01, 0xe0, 0x00, 0x03, 0xc0, 0x00, 0x00, 0x00, 0xf0, 0x00,
    0x03, 0x80, 0x00, 0x00, 0x00, 0x70, 0x00, 0x03, 0x80, 0x00, 0x00, 0x00,
    0x70, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

// 'Card_icon', 68x50px
// This icon is used to represent the card
static const unsigned char PROGMEM cardBitmap[] = {
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x01, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x7f, 0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0f, 0xff, 0x78, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x03, 0xff, 0xc0, 0x18, 0x00, 0x00, 0x00, 0x00,
    0x00, 0xff, 0xf0, 0x00, 0x18, 0x00, 0x00, 0x00, 0x00, 0x1f, 0xfe, 0x00,
    0x00, 0x1c, 0x00, 0x00, 0x00, 0x07, 0xff, 0xc0, 0x00, 0x00, 0x0c, 0x00,
    0x00, 0x01, 0xff, 0xe0, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x00, 0x3f, 0xfc,
    0x00, 0x00, 0x00, 0x00, 0x0c, 0x00, 0x07, 0xff, 0xc0, 0x00, 0x00, 0x00,
    0x00, 0x0c, 0x00, 0x3f, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x0e, 0x00,
    0x38, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x06, 0x00, 0x70, 0x00, 0x00,
    0x00, 0x00, 0x01, 0xc0, 0x06, 0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x0f,
    0xf0, 0x06, 0x00, 0x60, 0x00, 0x00, 0x00, 0x00, 0x1f, 0xf8, 0x06, 0x00,
    0x60, 0x00, 0x00, 0x00, 0x00, 0x3f, 0xfc, 0x06, 0x00, 0x70, 0x00, 0x00,
    0x00, 0x00, 0x3f, 0x9c, 0x07, 0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x38,
    0x0e, 0x07, 0x00, 0x30, 0x00, 0x00, 0x00, 0x00, 0x38, 0x4e, 0x03, 0x00,
    0x30, 0x00, 0x00, 0x00, 0x00, 0x38, 0x0e, 0x03, 0x00, 0x30, 0x00, 0x20,
    0x00, 0x00, 0x38, 0x0e, 0x03, 0x00, 0x30, 0x07, 0xf0, 0x00, 0x00, 0x38,
    0x0e, 0x03, 0x00, 0x38, 0x1f, 0xf0, 0x00, 0x00, 0x3c, 0x1e, 0x03, 0x80,
    0x18, 0x1f, 0xf0, 0x00, 0x00, 0x3e, 0x1e, 0x01, 0x80, 0x18, 0x1f, 0xf0,
    0x00, 0x00, 0x1f, 0x01, 0x01, 0x80, 0x18, 0x1f, 0xf8, 0x00, 0x00, 0x1c,
    0x01, 0xc1, 0x80, 0x18, 0x1f, 0xf8, 0x00, 0x00, 0x10, 0x03, 0xc1, 0x80,
    0x18, 0x0f, 0xf8, 0x00, 0x00, 0x38, 0x07, 0xc1, 0xc0, 0x0c, 0x0f, 0xc0,
    0x00, 0x00, 0x3c, 0x1f, 0xc0, 0xc0, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x3f,
    0xff, 0x00, 0xc0, 0x0c, 0x00, 0x00, 0x00, 0x00, 0x3f, 0xf8, 0x00, 0xc0,
    0x0c, 0x00, 0x00, 0x00, 0x00, 0x1f, 0x00, 0x00, 0xc0, 0x0c, 0x00, 0x00,
    0x1f, 0xe0, 0x00, 0x00, 0x00, 0xe0, 0x0e, 0x00, 0x03, 0xff, 0xc0, 0x00,
    0x00, 0x00, 0xe0, 0x06, 0x00, 0x3f, 0xfc, 0x00, 0x00, 0x00, 0x00, 0xe0,
    0x06, 0x03, 0xfe, 0x00, 0x00, 0x00, 0x00, 0x00, 0xc0, 0x06, 0x03, 0xc0,
    0x00, 0x00, 0x00, 0x00, 0x0f, 0xc0, 0x06, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x01, 0xff, 0x80, 0x07, 0x00, 0x00, 0x00, 0x00, 0x00, 0x7f, 0xf8, 0x00,
    0x07, 0x00, 0x00, 0x00, 0x00, 0x1f, 0xfe, 0x00, 0x00, 0x03, 0x00, 0x00,
    0x00, 0x03, 0xff, 0xc0, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0xff, 0xf8,
    0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x3f, 0xfe, 0x00, 0x00, 0x00, 0x00,
    0x03, 0x00, 0x07, 0xff, 0xc0, 0x00, 0x00, 0x00, 0x00, 0x03, 0x80, 0xff,
    0xf0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x01, 0xff, 0xfc, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0xff, 0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00};

// Define ESP32 RTOS task method
void TaskLoadingBar(void *pvParameters);
void TaskMain(void *pvParameters);
void TaskRegister(void *pvParameters);
void TaskAttendance(void *pvParameters);
void TaskCheckConnection(void *pvParameters);

/**
 * @brief Split a string by a given delimiter.
 * This function takes an input string and a delimiter character,
 * and splits the string into an ArrayList of substrings based
 * on the delimiter.
 *
 * @param str The input string to be split.
 * @param delimiter The character used as the delimiter.
 * @return An ArrayList containing the split substrings.
 */
ArrayList<String> splitString(const String &str, char delimiter) {
  ArrayList<String> result;
  String temp = "";
  for (unsigned int i = 0; i < str.length(); i++) {
    if (str[i] == delimiter) {
      result.add(temp);
      temp = "";
    } else {
      temp += str[i];
    }
  }
  if (temp.length() > 0) {
    result.add(temp);
  }
  return result;
}

/**
 * @brief Load settings from the Preferences database.
 * This function reads the current event name, show division setting,
 * and sound setting from the Preferences database. If the keys
 * don't exist, it sets default values and saves them to the
 * Preferences database.
 */
void loadSettings() {
  // Read current event from Preferences Database
  // If the key doesn't exist, read from PostmanAPI Database
  // Otherwise, read the value from the Preferences database
  HashMap<String, String> eventsColumn;
  eventsColumn.put("judul", "current_event_name");
  HashMap<String, String> eventsData =
      api.readData("/api/event", "", eventsColumn);

  if (pref.getString("event_name", "").equals("")) {
    pref.putString("event_name", eventsData.get("current_event_name"));
    currentEvent = eventsData.get("current_event_name");
  } else {
    currentEvent = pref.getString("event_name");
  }
}

/**
 * @brief Get the string representation of the presence option.
 * This function takes a PresenceOption enum value and returns
 * the corresponding string representation.
 *
 * @param option The PresenceOption enum value.
 * @return A string representation of the presence option.
 */
String getPresenceOption(PresenceOption option) {
  switch (option) {
  case PresenceOption::BPHI:
    return "BPHI";
  case PresenceOption::COMMITTEE:
    return "PANITIA";
  case PresenceOption::PARTICIPANT:
    return "PESERTA";
  default:
    return "UNKNOWN";
  }
}

/**
 * @brief Setup function for the ESP32 system.
 * This function initializes the system components
 * and starts the main tasks.
 */
void setup() {
  // Initialize Serial Monitor
  Serial.begin(115200);
  WiFi.mode(WIFI_STA);
  Serial.println();

  // Initialize system components pinout
  SPI.begin(18, 19, 23, SS_PIN);
  rfid.PCD_Init();

  Wire.begin(17, 16);
  if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_SCREEN_ADDRESS)) {
    Serial.println("SSD1306 allocation failed!");
    while (1)
      ; // Don't proceed, loop forever
  }

  display.display();
  delay(2000);

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setFont(&FreeSansBold7pt7b);

  xTaskCreate(TaskLoadingBar, "Loading Bar", 2048, NULL, 1,
              &taskLoadingHandler);

  ReceiverPort.begin(115200, SERIAL_8N1, 26, -1);
  TransmitterPort.begin(115200, SERIAL_8N1, -1, 27);

  JsonDocument doc;
  String callbackData;
  doc["dataType"] = "RTDATA";

  JsonObject data = doc["data"].to<JsonObject>();
  data["wifiStatusCode"] = 0;
  serializeJson(doc, callbackData);
  TransmitterPort.println(callbackData);

  char buffer[128]; // Buffer to hold input data
  String inputData = "";
  size_t readData = -1;

  // Input WiFi Credentials from Serial Monitor
  Serial.println("Input WiFi Credentials:");
  Serial.print("SSID: ");
  while (true) {
    String callbackData;

    ReceiverPort.setTimeout(
        10000L); // Wait until 10 seconds for input from serial
    readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
    buffer[readData] = '\0'; // Null-terminate C-string

    // Convert to Arduino String
    inputData = String(buffer);
    inputData.trim();

    if (inputData.equals("")) {
      buffer[0] = '\0'; // Clear buffer
      continue;
    }

    Serial.println(inputData);
    JsonDocument doc;
    DeserializationError deserializeError = deserializeJson(doc, inputData);
    if (deserializeError != deserializeError.Ok) {
      Serial.print("Deserialize data failed: ");
      Serial.println(deserializeError.c_str());

      JsonDocument callbackDoc;
      callbackDoc["dataType"] = "DATA";

      JsonObject data = callbackDoc["data"].to<JsonObject>();
      data["wifiStatusCode"] = -1;

      serializeJson(callbackDoc, callbackData);
      TransmitterPort.println(callbackData);
      continue;
    }

    String ssid = doc["ssid"];
    String password = doc["password"];

    Serial.printf("SSID : %s Password : %s InputData : %s", ssid.c_str(),
                  password.c_str(), inputData.c_str());

    WiFi.begin(ssid.c_str(), password.c_str());

    while (WiFi.status() != WL_CONNECTED) {
      currentWiFiDot++;
      if (currentWiFiDot == 0) {
        Serial.print("Connecting to WiFi");
      } else {
        Serial.print(".");

        if (currentWiFiDot == 5) {
          Serial.println();
          currentWiFiDot = -1;
        }
      }

      // Check for WiFi connection timeout
      if (MAX_WIFI_RETRIES-- == 0) {
        Serial.println();
        Serial.println();
        Serial.println("Failed to connect to WiFi!");
        Serial.println("Try again with different SSID and Password.");
        Serial.println();

        JsonDocument callbackDoc;
        callbackDoc["dataType"] = "DATA";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["wifiStatusCode"] = 0;

        serializeJson(callbackDoc, callbackData);
        TransmitterPort.println(callbackData);
        delay(2500);

        MAX_WIFI_RETRIES = 32;
        currentWiFiDot = -1;
        Serial.println("Input WiFi Credentials:");
        Serial.println("SSID: ");
        break;
      }

      delay(500);
    }

    if (WiFi.status() == WL_CONNECTED) {
      JsonDocument callbackDoc;
      callbackDoc["dataType"] = "DATA";

      JsonObject data = callbackDoc["data"].to<JsonObject>();
      data["wifiStatusCode"] = 1;

      serializeJson(callbackDoc, callbackData);
      TransmitterPort.println(callbackData);

      ReceiverPort.setTimeout(1000L);
      break;
    }
  }

  Serial.println();
  Serial.println("Connected to WiFi!");
  Serial.print("IP address: ");
  Serial.println(WiFi.localIP());
  Serial.println();
  delay(500);

  // Connect to PostmanAPI Server
  Serial.println("Connecting to PostmanAPI Server...");
  if (api.begin()) {
    Serial.println("PostmanAPI Server connected!");
  } else {
    Serial.println("Failed to connect to PostmanAPI Server!");
    while (1)
      ; // Don't proceed, loop forever
  }
  Serial.println();
  delay(500);

  // Connect to Preferences Database
  Serial.println("Connecting to Preferences Database...");
  if (pref.begin("presensiIDCard", false)) {
    Serial.println("Preferences Database connected!");
  } else {
    Serial.println("Failed to connect to Preferences Database!");
    while (1)
      ; // Don't proceed, loop forever
  }
  delay(1500);
  vTaskDelete(taskLoadingHandler);

  // Start the tasks for each system
  xTaskCreate(TaskMain, "Main Menu", 8192, NULL, 1, &taskMainHandler);
  xTaskCreatePinnedToCore(TaskRegister, "Register Data", 8192, NULL, 1,
                          &taskRegisterHandler, 1);
  xTaskCreate(TaskAttendance, "Member Attendance", 8192, NULL, 1,
              &taskAttendanceHandler);

  xTaskCreate(TaskCheckConnection, "Check Connection", 8192, NULL, 2,
              &taskCheckConnectionHandler);

  vTaskSuspend(taskRegisterHandler);   // Suspend the register task
  vTaskSuspend(taskAttendanceHandler); // Suspend the attendance task

  // Initialize NTP Client
  ntpClient.begin();
  ntpClient.forceUpdate();
  MAX_WIFI_RETRIES = 32;

  loadSettings();           // Load settings from Preferences Database
  Serial.setTimeout(1000L); // Reset timeout for serial input
}

/**
 * @brief Check if a character is a digit.
 * This function checks if the given character is a digit (0-9).
 *
 * @param c The character to check.
 * @return true if the character is a digit, false otherwise.
 */
bool isDigitString(const String &str) {
  for (unsigned int i = 0; i < str.length(); i++) {
    if (!isDigit(str[i])) {
      return false;
    }
  }
  return true;
}

/**
 * @brief Register data from RFID Card.
 * This function reads the UID from the RFID Card and prompts the user to enter
 * their NIM, name, and division. It then writes this data to the PostmanAPI
 * database.
 */
void registerData() {
  HashMap<String, String> memberData;
  char buffer[64]; // Buffer to hold input data

  // Check if a card is present and read its UID
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    Serial.println("Waiting for a card...");
    TransmitterPort.println("Waiting for a card...");
    return;
  }

  String callbackData;
  JsonDocument callbackDoc;
  callbackDoc["dataType"] = "DATA";

  JsonObject data = callbackDoc["data"].to<JsonObject>();
  data["onRegisterCard"] = true;
  serializeJson(callbackDoc, callbackData);
  TransmitterPort.println(callbackData);

  Serial.println();
  Serial.println("**Card Detected!**");
  TransmitterPort.println(
      "</nl>Card Detected!"); // </nl> for new line, it will converted in the
                              // app side to \n

  // Get the UID of the card
  String memberUID = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    memberUID += rfid.uid.uidByte[i] < 0x10 ? " 0" : " ";
    memberUID += String(rfid.uid.uidByte[i], HEX);
  }

  String inputData = "";
  size_t readData = -1;
  ReceiverPort.setTimeout(
      60000L); // Wait until 60 seconds for input from serial

  Serial.println("============] Register Member [============");
  Serial.println("Please enter member data below:");
  Serial.println("Note: You can type 'Cancel' to cancel the registration.");

  TransmitterPort.println("======] Register Member [======");
  TransmitterPort.println("Please enter member data below:");
  TransmitterPort.println("You can type 'Cancel' to cancel the registration.");
  Serial.println();

  memberUID.trim();
  memberUID.toUpperCase();
  Serial.print("Member Card UID: ");
  Serial.println(memberUID);
  TransmitterPort.printf("</nl>Member Card UID: %s\n", memberUID.c_str());
  memberData.put("uid", memberUID);

  // ===================[ Prompt for NIM ]===================
  Serial.print("Write Member NIM: ");
  TransmitterPort.println("Write Member NIM: ");

  // Read until newline or buffer is full
  readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
  buffer[readData] = '\0'; // Null-terminate C-string

  // Convert to Arduino String
  inputData = String(buffer);
  inputData.trim();

  // If input is Cancel or no input is received, cancel the registration
  if (inputData.equals("")) {
    Serial.println("Timeout for waiting input data! Try again later.");
    TransmitterPort.println(
        "</nl>Timeout for waiting input data! Try again later.</nl>");
    Serial.println();
    return;
  } else if (inputData.equalsIgnoreCase("Cancel")) {
    Serial.println("Register data has been canceled!");
    TransmitterPort.println("</nl>Register data has been canceled!</nl>");
    Serial.println();
    return;
  }

  JsonDocument memberDataDoc;
  DeserializationError deserializeError =
      deserializeJson(memberDataDoc, inputData);

  if (!deserializeError) {
    String division = memberDataDoc[0];
    String name = memberDataDoc[1];
    String nim = memberDataDoc[2];

    Serial.println(nim);
    Serial.println("Write Member Name: " + name);
    Serial.println("Write Member Division: " + division);

    memberData.put("nim", nim);
    memberData.put("nama", name);
    memberData.put("divisi", division);
  } else {
    String nimAnggota = inputData;
    Serial.println(nimAnggota);
    memberData.put("nim", nimAnggota);
    buffer[0] = '\0'; // Clear buffer

    // ===================[ Prompt for Name ]===================
    Serial.print("Write Member Name: ");
    TransmitterPort.println("Write Member Name: ");

    // Read until newline or buffer is full
    readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
    buffer[readData] = '\0'; // Null-terminate C-string

    // Convert to Arduino String
    inputData = String(buffer);
    inputData.trim();

    // If input is Cancel or no input is received, cancel the registration
    if (inputData.equals("")) {
      Serial.println("Timeout for waiting input data! Try again later.");
      TransmitterPort.println(
          "</nl>Timeout for waiting input data! Try again later.</nl>");
      Serial.println();
      return;
    } else if (inputData.equalsIgnoreCase("Cancel")) {
      Serial.println("Register data has been canceled!");
      TransmitterPort.println("</nl>Register data has been canceled!</nl>");
      Serial.println();
      return;
    }

    String namaAnggota = inputData;
    Serial.println(namaAnggota);
    memberData.put("nama", namaAnggota);
    buffer[0] = '\0'; // Clear buffer

    // =================[ Prompt for Division ]=================
    HashMap<String, String> divisionList;
    divisionList.put("RISTEK", "Riset dan Teknologi");
    divisionList.put("KEOR", "Keorganisasian");
    divisionList.put("HUBPUB", "Hubungan Publik");
    divisionList.put("BPI", "Badan Pengurus Inti");

    Serial.println("============] Division List [============");
    Serial.println("Please select your division from the list below:");
    Serial.println("1. Riset dan Teknologi");
    Serial.println("2. Keorganisasian");
    Serial.println("3. Hubungan Publik");
    Serial.println("4. Badan Pengurus Harian Inti");

    TransmitterPort.println("</nl>======] Division List [======");
    TransmitterPort.println("Please select your division from the list below:");
    TransmitterPort.println("1. Riset dan Teknologi");
    TransmitterPort.println("2. Keorganisasian");
    TransmitterPort.println("3. Hubungan Publik");
    TransmitterPort.println("4. Badan Pengurus Harian Inti");
    Serial.println();

    while (true) {
      buffer[0] = '\0'; // Clear buffer
      Serial.print("Write Number of Member Division: ");
      TransmitterPort.println("</nl>Write Number Division: ");

      // Read until newline or buffer is full
      readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
      buffer[readData] = '\0'; // Null-terminate C-string

      // Convert to Arduino String
      inputData = String(buffer);
      inputData.trim();

      // If input is Cancel or no input is received, cancel the registration
      if (inputData.equals("")) {
        Serial.println("Timeout for waiting input data! Try again later.");
        TransmitterPort.println(
            "</nl>Timeout for waiting input data! Try again later.</nl>");
        Serial.println();
        return;
      } else if (inputData.equalsIgnoreCase("Cancel")) {
        Serial.println("Register data has been canceled!");
        TransmitterPort.println("</nl>Register data has been canceled!</nl>");
        Serial.println();
        return;
      }

      // Check for valid input
      // If input is not digit, continue to prompt
      // If input is out of range or under 1, continue to prompt
      if (!isDigitString(inputData)) {
        Serial.println("Input number must be Integer!");
        TransmitterPort.println("Input number must be Integer!");
        Serial.println();
        continue;
      } else if (!(inputData.toInt() <= divisionList.size() &&
                   inputData.toInt() > 0)) {
        Serial.printf("Invalid option! Range must be in 1-%d.",
                      divisionList.size());
        TransmitterPort.printf("Invalid option! Range must be in 1-%d.\n",
                               divisionList.size());
        Serial.println();
        continue;
      }

      // Map input to division key
      switch (inputData.toInt()) {
      case 1:
        inputData = "RISTEK";
        break;
      case 2:
        inputData = "KEOR";
        break;
      case 3:
        inputData = "HUBPUB";
        break;
      case 4:
        inputData = "BPHI";
        break;
      }
      break;
    }

    String namaDivisiSingkat = inputData;
    String namaDivisiLengkap = divisionList.get(inputData);
    Serial.println(namaDivisiLengkap);
    memberData.put("divisi", namaDivisiSingkat);
    buffer[0] = '\0'; // Clear buffer
  }

  // Stop reading the card
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  delay(500);

  // Save member data to PostmanAPI database
  Serial.println("Write data to PostmanAPI database...");
  TransmitterPort.println("</nl>Write data to PostmanAPI database...");
  delay(1000);

  JsonDocument test = memberData.toJson();
  Serial.println(test.as<String>());

  bool success = api.createData("/api/mahasiswa", memberData.toJson());
  if (success) {
    Serial.println("Successfully wrote data to PostmanAPI database!");
    TransmitterPort.println(
        "Successfully wrote data to PostmanAPI Server!</nl>");
  } else {
    Serial.println("Failed to write data to PostmanAPI database!");
    TransmitterPort.println("Failed to write data to PostmanAPI Server!");
    TransmitterPort.printf("Caused: %s (%d)</nl></nl>\n",
                           api.getResponse().c_str(), api.getResponseCode());
  }

  delay(1500);
  Serial.println();
}

/**
 * @brief Show member data on the OLED display and Serial Monitor.
 * This function retrieves member data from the PostmanAPI database
 * using the provided UID. It displays the member's identity.
 * If the member is not found, it shows an error message on the display.
 *
 * @param UID The UID Card of the member.
 * @param showDivision If true, the member's division will be displayed.
 * @param showOnLED If true, the member data will be displayed on the OLED.
 *                  Otherwise, it will only print data to the Serial Monitor.
 *
 * @note This function uses the PostmanAPI to retrieve member data.
 */
void showMemberData(String UID, bool showOnLED = true) {
  String *memberUID = api.getMemberByUID("/api/mahasiswa", UID);

  // Check if member exists in PostmanAPI database
  if (memberUID == nullptr) {
    Serial.printf("Member with UID %s isn't exists in member table!\n", UID);
    TransmitterPort.printf(
        "</nl>Member with UID %s isn't exists in member table!</nl></nl>\n",
        UID);

    display.clearDisplay();
    display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
    display.setCursor(8, 60);
    display.print("Invalid UID Data!");
    display.display();
    return;
  }

  // Map member data to display columns
  HashMap<String, String> column;
  column.put("uid", "Member UID");
  column.put("nim", "Member NIM");
  column.put("nama", "Member Name");
  if (showDivision)
    column.put("divisi", "Member Division");
  HashMap<String, String> memberData =
      api.readData("/api/mahasiswa", UID, column);

  // Print member data to Serial Monitor
  Serial.println("=========] Member Data [=========");
  TransmitterPort.println("=========] Member Data [=========");
  memberData.foreach ([](const String &colName, const String &colValue) {
    Serial.println(colName + ": " + colValue);
    TransmitterPort.println(colName + ": " + colValue);
  });
  Serial.println("=================================");
  TransmitterPort.println("=================================</nl>");

  // Print member data to OLED display
  // If showOnLED is true, display the member data on the OLED
  // Otherwise, only print to Serial Monitor
  if (showOnLED) {
    display.clearDisplay();
    display.setFont(&FreeSansBold6pt7b);
    display.drawBitmap(0, 0, userBitmap, 50, 60, SSD1306_WHITE);

    int currentY = showDivision ? 8 : 16;
    int currentLine = 1;
    memberData.foreach ([&currentY, &currentLine](const String &colName,
                                                  const String &colValue) {
      display.setCursor(52, currentY);
      if (currentLine != 3) {
        display.print(colValue);
      } else {
        ArrayList<String> namePart = splitString(colValue, ' ');
        String firstName = namePart.get(0);
        String lastName;

        for (int i = 1; i < namePart.size(); i++) {
          String subname = namePart.get(i);

          if (subname.startsWith("'")) {
            lastName += subname.substring(1, 2);
          } else {
            lastName += subname.substring(0, 1);
          }
          lastName += ". ";
        }
        lastName.trim();

        String name = firstName + " " + lastName;
        name.trim();
        display.print(name);
      }
      currentY += 16;
      currentLine++;
    });
    display.display();
    display.setFont(&FreeSansBold7pt7b);
  }
}

/**
 * @brief Show the attendance menu.
 * This function displays the attendance options
 * on the Serial Monitor. It provides options for the user to mark attendance
 * as a participant, committee, BPHI, or manually mark attendance.
 */
void showAttendanceMenu() {
  Serial.println();
  Serial.println("=========] Attendance Options [=========");
  Serial.println("Press 1: As a Participant");
  Serial.println("Press 2: As a Committee");
  Serial.println("Press 3: Manual Attendance");
  Serial.println("Press 4: Back to previous menu");
  Serial.println("========================================");
  Serial.println();

  display.clearDisplay();
  display.setCursor(2, 24);
  display.print("See Serial Monitor");
  display.setCursor(0, 42);
  display.print("for Menu Selection!");
  display.display();
}

/**
 * @brief Mark attendance for a member.
 * This function to mark attendance of member by reading
 * their UID from the RFID card. It updates the attendance
 * records in the PostmanAPI database based on the member's UID.
 *
 * @param UID The UID Card of the member.
 * @param option The type of attendance (BPHI, Committee, or Participant).
 */
void memberAttendance(String UID, PresenceOption option) {
  Serial.println("Fetching member UID to database...");
  TransmitterPort.println("Fetching member UID to database...");
  delay(500);

  // Check if member exists in PostmanAPI database
  String *memberID = api.getMemberByUID("/api/mahasiswa", UID);
  if (memberID == nullptr) {
    Serial.printf("Member with UID %s isn't exists in member table!\n", UID);
    TransmitterPort.printf(
        "Member with UID %s isn't exists in member table!</nl></nl>\n", UID);

    display.clearDisplay();
    display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
    display.setCursor(10, 60);
    display.print("Invalid ID Data!");
    display.display();

    delay(1500);
    Serial.println();
    return;
  }

  HashMap<String, String> optionColumn;
  optionColumn.put("divisi", "presence_mode");
  HashMap<String, String> logsData =
      api.readData("/api/mahasiswa", UID, optionColumn);

  String presenceMode = optionColumn.get("presence_mode");
  if (presenceMode.equalsIgnoreCase("BPHI")) {
    option = PresenceOption::BPHI;
  }

  if (ntpClient.forceUpdate()) {
    String formattedCurrDate = ntpClient.getFormattedDate();
    String currentDate = splitString(formattedCurrDate, 'T').get(0);

    HashMap<String, String> logsColumn;
    logsColumn.put("tanggal_masuk", "last_login");
    HashMap<String, String> logsData =
        api.readData("/api/mahasiswa", UID, logsColumn);

    bool isLoggedIn = logsData.get("last_login") != nullptr;

    HashMap<String, String> eventsColumn;
    eventsColumn.put("judul", "event_name");
    HashMap<String, String> eventsData =
        api.readData("/api/event", "", eventsColumn);
    String eventName = eventsData.get("event_name");

    // Check if member has already logged in for the current event today
    if (isLoggedIn && eventName.equals(currentEvent)) {
      String logInDateTime = logsData.get("last_login");
      String logInDate = splitString(logInDateTime, 'T').get(0);

      // Check if member has already attended today
      if (logInDate.equals(currentDate)) {
        Serial.printf("Member with UID %s has already attended today!\n", UID);
        TransmitterPort.printf(
            "Member with UID %s has already attended today!</nl></nl>\n", UID);

        display.clearDisplay();
        display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
        display.setCursor(12, 60);
        display.print("Already Log In!");
        display.display();

        delay(1500);
        Serial.println();
        return;
      } else if (!logInDate.equals(currentDate) &&
                 eventName.equals(currentEvent)) {
        Serial.printf("Member with UID %s has already attended on event %s!\n",
                      UID, eventName.c_str());
        TransmitterPort.printf(
            "Member with UID %s has already attended on event %s!</nl></nl>\n",
            UID, eventName.c_str());

        display.clearDisplay();
        display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
        display.setCursor(12, 60);
        display.print("Already Log In!");
        display.display();

        delay(1500);
        Serial.println();
        return;
      }
    }

    // Update current event name in preferences if changed
    if (!eventName.equals(currentEvent)) {
      pref.putString("event_name", eventName);
      currentEvent = pref.getString("event_name");
    }

    HashMap<String, String> attendanceData;
    attendanceData.put("uid", UID);
    attendanceData.put("role", getPresenceOption(option));

    bool success = api.createData("/api/log/masuk", attendanceData.toJson());

    if (success) {
      Serial.println("Successfully wrote data to PostmanAPI Server!");
      TransmitterPort.println(
          "</nl>Successfully wrote data to PostmanAPI Server!");
      delay(500);
      Serial.println();
      Serial.printf("Member with UID %s doing Log In attendance on %s!\n", UID,
                    currentDate);
      TransmitterPort.printf(
          "Member with UID %s doing Log In attendance on %s!</nl></nl>\n", UID,
          currentDate);

      display.clearDisplay();
      display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
      display.setCursor(12, 60);
      display.print("Success Log In!");
      display.display();
      delay(500);

      showMemberData(UID);
    } else {
      Serial.println("Failed to write data to PostmanAPI Server!");
      TransmitterPort.println(
          "Failed to write data to PostmanAPI Server!</nl>");
      display.clearDisplay();
      display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
      display.setCursor(2, 60);
      display.print("Failed Presence!");
      display.display();
    }
  } else {
    Serial.println("Failed to update NTP time!");
    Serial.println("Please check your internet connection.");
    TransmitterPort.println("</nl>Failed to update NTP time!");
    TransmitterPort.println("Please check your internet connection.</nl>");
  }

  delay(5000);
  Serial.println();
}

/**
 * @brief Manually mark attendance for a member.
 * This function allows the user to manually enter a member's name
 * to mark their attendance. It prompts the user for input and
 * saves the attendance data to the PostmanAPI Server.
 */
void manualAttendance() {
  HashMap<String, String> memberData;
  char buffer[64]; // Buffer to hold input data

  String callbackData;
  JsonDocument callbackDoc;
  callbackDoc["dataType"] = "DATA";

  JsonObject data = callbackDoc["data"].to<JsonObject>();
  data["onManualPresence"] = true;
  serializeJson(callbackDoc, callbackData);
  TransmitterPort.println(callbackData);

  String inputData = "";
  size_t readData = -1;
  ReceiverPort.setTimeout(
      60000L); // Wait until 60 seconds for input from serial

  Serial.println("===========] Manual Attendance [===========");
  Serial.println("Please enter member name and nim you want to be marked:");
  Serial.println("Note: You can type 'Cancel' to cancel the attendance.");
  Serial.println();

  TransmitterPort.println("======] Manual Presence [======");
  TransmitterPort.println(
      "Please enter member name and nim you want to be marked:");
  TransmitterPort.println("You can type 'Cancel' to cancel the presence.</nl>");

  // ===================[ Prompt for Name ]===================
  Serial.print("Write Member Name: ");
  TransmitterPort.println("Write Member Name: ");

  // Read until newline or buffer is full
  readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
  buffer[readData] = '\0'; // Null-terminate C-string

  // Convert to Arduino String
  inputData = String(buffer);
  inputData.trim();

  // If input is Cancel or no input is received, cancel the registration
  if (inputData.equals("")) {
    Serial.println("Timeout for waiting input data! Try again later.");
    TransmitterPort.println(
        "</nl>Timeout for waiting input data! Try again later.</nl>");
    Serial.println();
    return;
  } else if (inputData.equalsIgnoreCase("Cancel")) {
    Serial.println("Register data has been canceled!");
    TransmitterPort.println("</nl>Register data has been canceled!</nl>");
    Serial.println();
    return;
  }

  String namaAnggota = inputData;
  Serial.println(namaAnggota);
  memberData.put("nama", namaAnggota);
  buffer[0] = '\0'; // clear buffer

  // ===================[ Prompt for NIM ]===================
  Serial.print("Write Member NIM: ");
  TransmitterPort.println("Write Member NIM: ");

  // Read until newline or buffer is full
  readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
  buffer[readData] = '\0'; // Null-terminate C-string

  // Convert to Arduino String
  inputData = String(buffer);
  inputData.trim();

  // If input is Cancel or no input is received, cancel the registration
  if (inputData.equals("")) {
    Serial.println("Timeout for waiting input data! Try again later.");
    TransmitterPort.println(
        "</nl>Timeout for waiting input data! Try again later.</nl>");
    Serial.println();
    return;
  } else if (inputData.equalsIgnoreCase("Cancel")) {
    Serial.println("Register data has been canceled!");
    TransmitterPort.println("</nl>Register data has been canceled!</nl>");
    Serial.println();
    return;
  }

  String nimAnggota = inputData;
  Serial.println(nimAnggota);
  memberData.put("nim", nimAnggota);
  buffer[0] = '\0'; // clear buffer

  // Save member attendance data to PostmanAPI database
  Serial.println("Write data to PostmanAPI database...");
  TransmitterPort.println("</nl>Write data to PostmanAPI database...");
  delay(500);

  // Check if member exists in PostmanAPI database
  String *memberCardUID = api.getMemberByName("/api/mahasiswa", namaAnggota);
  if (memberCardUID == nullptr) {
    Serial.printf("Member with name %s isn't exists in member table!\n",
                  namaAnggota.c_str());
    TransmitterPort.printf(
        "Member with name %s isn't exists in member table!</nl></nl>\n",
        namaAnggota.c_str());

    delay(1500);
    Serial.println();
    return;
  }

  if (ntpClient.forceUpdate()) {
    String formattedCurrDate = ntpClient.getFormattedDate();
    String currentDate = splitString(formattedCurrDate, 'T').get(0);

    HashMap<String, String> logsColumn;
    logsColumn.put("tanggal_masuk", "last_login");
    HashMap<String, String> logsData =
        api.readData("/api/mahasiswa", *memberCardUID, logsColumn);

    bool isLoggedIn = logsData.get("last_login") != nullptr;

    HashMap<String, String> eventsColumn;
    eventsColumn.put("judul", "event_name");
    HashMap<String, String> eventsData =
        api.readData("/api/event", "", eventsColumn);
    String eventName = eventsData.get("event_name");

    // Check if member has already logged in for the current event today
    if (isLoggedIn && eventName.equals(currentEvent)) {
      String logInDateTime = logsData.get("last_login");
      String logInDate = splitString(logInDateTime, 'T').get(0);

      // Check if member has already attended today
      if (logInDate.equals(currentDate)) {
        Serial.printf("Member with UID %s has already attended today!\n",
                      *memberCardUID);
        TransmitterPort.printf(
            "Member with UID %s has already attended today!</nl></nl>\n",
            *memberCardUID);

        display.clearDisplay();
        display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
        display.setCursor(12, 60);
        display.print("Already Log In!");
        display.display();

        delay(1500);
        Serial.println();
        return;
      } else if (!logInDate.equals(currentDate) &&
                 eventName.equals(currentEvent)) {
        Serial.printf("Member with UID %s has already attended on event %s!\n",
                      *memberCardUID, eventName.c_str());
        TransmitterPort.printf(
            "Member with UID %s has already attended on event %s!</nl></nl>\n",
            *memberCardUID, eventName.c_str());

        display.clearDisplay();
        display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
        display.setCursor(12, 60);
        display.print("Already Log In!");
        display.display();

        delay(1500);
        Serial.println();
        return;
      }
    }

    // Update current event name in preferences if changed
    if (!eventName.equals(currentEvent)) {
      pref.putString("event_name", eventName);
      currentEvent = pref.getString("event_name");
    }

    bool success = api.createData("/api/log/izin", memberData.toJson());
    if (success) {
      Serial.println("Successfully wrote data to PostmanAPI database!");
      TransmitterPort.println("Successfully wrote data to PostmanAPI Server!");
      delay(500);
      Serial.println();
      Serial.printf("You forced Member with UID %s to absent on %s!\n",
                    *memberCardUID, currentDate);
      TransmitterPort.printf(
          "You forced Member with UID %s to absent on %s!</nl></nl>\n",
          *memberCardUID, currentDate);
      delay(500);

      showMemberData(*memberCardUID, false);
    } else {
      Serial.println("Failed to write data to PostmanAPI Server!");
      TransmitterPort.println(
          "Failed to write data to PostmanAPI Server!</nl>");
    }
  } else {
    Serial.println("Failed to update NTP time!");
    Serial.println("Please check your internet connection!");
    TransmitterPort.println("</nl>Failed to update NTP time!");
    TransmitterPort.println("Please check your internet connection.</nl>");
  }

  delay(5000);
  Serial.println();
}

/**
 * @brief Fetch the UID of the card.
 * This function checks if a card is present and reads its UID.
 * If a card is detected, it retrieves the UID and formats it as a string.
 *
 * @note The UID is returned as a pointer to a String object.
 * @return A pointer to a String containing the UID of the card.
 */
String *getCardUID() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial())
    return nullptr;

  Serial.println();
  Serial.println("**Card Detected!**");
  TransmitterPort.println("</nl>Card Detected!");
  display.clearDisplay();
  display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
  display.setCursor(6, 60);
  display.print("ID Card Detected!");
  display.display();

  // Get the UID of the card
  String *memberUID = new String();
  for (byte i = 0; i < rfid.uid.size; i++) {
    *memberUID += rfid.uid.uidByte[i] < 0x10 ? " 0" : " ";
    *memberUID += String(rfid.uid.uidByte[i], HEX);
  }
  memberUID->trim();
  memberUID->toUpperCase();
  delay(500);

  // Stop reading the card
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
  return memberUID;
}

/**
 * @brief Show the main menu.
 * This function displays the main menu options
 * on the Serial Monitor. It provides options for the user to
 * register member data, mark attendance, or access the event menu.
 */
void showMenu() {
  Serial.println();
  Serial.println("============] Menu Options [============");
  Serial.println("Press 1: Register member data");
  Serial.println("Press 2: Member attendance");
  Serial.println("Press 3: Exit");
  Serial.println("========================================");
  Serial.println();

  display.clearDisplay();
  display.setCursor(2, 24);
  display.print("See Serial Monitor");
  display.setCursor(0, 42);
  display.print("for Menu Selection!");
  display.display();
}

/**
 * @brief Main loop function.
 * The loop function is empty because using FreeRTOS tasks
 * to handle the main functionality of the program.
 * All the tasks are running in parallel, so no need to
 * put any code in the loop function.
 * The tasks will run independently and handle their own logic.
 */
void loop() {
  // IGNORED
}

/**
 * @brief Handle displays a loading bar on the OLED screen.
 * This task will show a loading message with dots that
 * change every 500 milliseconds.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskLoadingBar(void *pvParameters) {
  (void)pvParameters;

  int currentLoadingDot = 0;

  for (;;) {
    currentLoadingDot++;
    display.clearDisplay();

    if (currentLoadingDot == 0) {
      display.setCursor(28, 32);
      display.print("Loading");
    } else if (currentLoadingDot == 1) {
      display.setCursor(28, 32);
      display.print("Loading.");
    } else if (currentLoadingDot == 2) {
      display.setCursor(28, 32);
      display.print("Loading..");
    } else if (currentLoadingDot == 3) {
      display.setCursor(28, 32);
      display.print("Loading...");
    } else if (currentLoadingDot == 4) {
      display.setCursor(28, 32);
      display.print("Loading....");
      currentLoadingDot = -1;
    }
    display.display();
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

/**
 * @brief Handle checking the WiFi connection status.
 * This task runs in a loop and checks if the ESP32 is connected to WiFi.
 * If the connection is lost, it will attempt to reconnect.
 * If the reconnection fails, it will delete the task and stop the program.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskCheckConnection(void *pvParameters) {
  (void)pvParameters;

  int wifiStatus;

  for (;;) {
    if (!WiFi.isConnected()) {
      if (!isDisconnected) {
        Serial.println("Connection Lost!");
        isDisconnected = true;
        wifiStatus = 2;
      }

      delay(1000);
      Serial.println("Trying to reconnect...");

      if (MAX_WIFI_RETRIES-- > 0) {
        if (WiFi.setAutoReconnect(true)) {
          isDisconnected = false;
          MAX_WIFI_RETRIES = 32;
          Serial.println("WiFi Reconnected!");
        }
      } else {
        Serial.println("Failed to Reconnect WiFi!");
        wifiStatus = 0;
        delay(500);
        vTaskDelete(NULL);
      }
    } else {
      wifiStatus = 1;
    }

    JsonDocument doc;
    String callbackData;
    doc["dataType"] = "RTDATA";

    JsonObject data = doc["data"].to<JsonObject>();
    data["wifiStatusCode"] = wifiStatus;
    serializeJson(doc, callbackData);

    TransmitterPort.println(callbackData);
    vTaskDelay(pdMS_TO_TICKS(1000));
  }
}

/**
 * @brief Read data received from the Serial Monitor.
 * This function reads data from the ReceiverPort until a newline character
 * is encountered or the buffer is full. It returns the received data as
 * a trimmed String.
 *
 * @return A String containing the received data.
 */
String readReceivedData() {
  char buffer[512]; // Buffer to hold input data
  size_t readData = -1;
  String receiveData = "";

  readData = ReceiverPort.readBytesUntil('\n', buffer, sizeof(buffer) - 1);
  buffer[readData] = '\0'; // Null-terminate C-string
  receiveData = String(buffer);
  receiveData.trim();
  return receiveData;
}

/**
 * @brief Handles the menu options and system.
 * This main task runs in a loop and waits for user input
 * from the Serial Monitor. It processes the input and updates
 * the main menu option accordingly. It also shows the appropriate
 * menus based on the current main menu option.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskMain(void *pvParameters) {
  (void)pvParameters;

  // Show the menu list once on the Serial Monitor
  showMenu();

  for (;;) {
    // Check if the system is disconnected or no data is available
    if (!WiFi.isConnected() || !ReceiverPort.available()) {
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    receivedData = readReceivedData();
    if (receivedData != "" && mainMenuOption == MainMenuOption::MAIN_MENU) {
#if DEBUG_ALL
      Serial.println(receivedData);
#endif

      int options = receivedData.toInt();
      receivedData = "";

      switch (options) {
      case 1:
        Serial.println("Opening register member data...");
        delay(500);

        mainMenuOption = MainMenuOption::REGISTER;
        vTaskResume(taskRegisterHandler); // Resume the register handler task
        vTaskSuspend(NULL);
        break;
      case 2:
        Serial.println("Opening attendance member data...");
        delay(500);

        mainMenuOption = MainMenuOption::ATTENDANCE;
        vTaskResume(
            taskAttendanceHandler); // Resume the attendance handler task
        vTaskSuspend(NULL);
        break;
      case 3:
        Serial.println("Exiting program...");
        delay(500);

        ESP.restart();
        break;
      default:
        Serial.println("Invalid menu option!");
      }
    }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

/**
 * @brief Handle the registration of member data.
 * This task runs in a loop and waits for the main menu
 * option to be set to REGISTER. When it is, it calls the
 * @ref registerData function to register member data from
 * the RFID card.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskRegister(void *pvParameters) {
  (void)pvParameters;

  for (;;) {
    // Check if the system is disconnected
    if (!WiFi.isConnected()) {
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    if (mainMenuOption == MainMenuOption::REGISTER) {
      // Read the mode from the Serial Monitor
      String option = ReceiverPort.readStringUntil('\n');
      option.trim();

      if (option != "" && option.equalsIgnoreCase("Cancel")) {
        Serial.println("Back to main menu");
        delay(500);

        showMenu();
        mainMenuOption = MainMenuOption::MAIN_MENU;

        vTaskResume(taskMainHandler); // Resume the main handler task
        vTaskSuspend(NULL);           // Suspend this task
      } else {
        registerData();
        ReceiverPort.setTimeout(1000L);

        String callbackData;
        JsonDocument callbackDoc;
        callbackDoc["dataType"] = "DATA";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["onRegisterCard"] = false;
        serializeJson(callbackDoc, callbackData);
        TransmitterPort.println(callbackData);
      }
    }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

/**
 * @brief Handle member attendance.
 * This task runs in a loop and waits for the main menu option to be set to
 * ATTENDANCE. When it is, it checks for a card UID and calls the
 * @ref memberAttendance function to mark the   member attendance.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskAttendance(void *pvParameters) {
  (void)pvParameters;

  for (;;) {
    // Check if the system is disconnected
    if (!WiFi.isConnected() || mainMenuOption != MainMenuOption::ATTENDANCE) {
      vTaskDelay(pdMS_TO_TICKS(1000));
      continue;
    }

    receivedData = readReceivedData();
    if (receivedData != "") {
#if DEBUG_ALL
      Serial.println(receivedData);
#endif

      int option = receivedData.toInt();
      receivedData = "";

      switch (option) {
      case 1:
        Serial.println("Presence member as Participant...");
        TransmitterPort.println("</nl>Presence member as Participant...");
        delay(1000);
        presenceOption = PresenceOption::PARTICIPANT;
        break;
      case 2:
        Serial.println("Presence member as Committee...");
        TransmitterPort.println("</nl>Presence member as Committee...");
        delay(1000);
        presenceOption = PresenceOption::COMMITTEE;
        break;
      case 3: {
        Serial.println("Manual attendance member...");
        TransmitterPort.println("</nl>Manual attendance member...");
        manualAttendance();

        String callbackData;
        JsonDocument callbackDoc;
        callbackDoc["dataType"] = "DATA";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["onManualPresence"] = false;
        serializeJson(callbackDoc, callbackData);
        TransmitterPort.println(callbackData);
        delay(1000);

        presenceOption = PresenceOption::NONE;
        ReceiverPort.setTimeout(1000L); // Reset timeout for serial input
        showAttendanceMenu();
        break;
      }
      case 4:
        Serial.println("Back to main menu");
        delay(500);

        showMenu();
        mainMenuOption = MainMenuOption::MAIN_MENU;
        presenceOption = PresenceOption::NONE;

        vTaskResume(taskMainHandler); // Resume the main handler task
        vTaskSuspend(NULL);           // Suspend this task
        break;
      default:
        Serial.println("Invalid menu option!");
      }
    }

    if (presenceOption != PresenceOption::NONE) {
      String *uid = getCardUID(); // Get the UID of the card

      // Check if the member UID card is valid
      if (uid != nullptr) {
        String memberUID = *uid;
        memberAttendance(memberUID, presenceOption);

        delete uid;
        uid = nullptr;
      } else {
        Serial.println("Please put member id card into RFID Reader...");
        TransmitterPort.println(
            "Please put member id card into RFID Reader...");

        display.clearDisplay();
        display.drawBitmap(32, 0, cardBitmap, 68, 50, SSD1306_WHITE);
        display.setCursor(6, 60);
        display.print("Tap Your ID Card!");
        display.display();
      }
    }
    vTaskDelay(pdMS_TO_TICKS(500));
  }
}
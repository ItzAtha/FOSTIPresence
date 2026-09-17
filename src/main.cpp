// ==========================[ SIMCOM A7670E ]==========================
// Define the RX buffer size for TinyGSM
#define TINY_GSM_RX_BUFFER 1024

// Import package for SIMCOM A7670E modem
#include <TinyGsmClient.h>

// Define Serial use for SIMOM A7670E
#define SerialAT Serial1

// Define modem pin and baud
#define MODEM_RX 25
#define MODEM_TX 26
#define MODEM_BAUD 115200

// Create instance of SIMCOM A7670E
TinyGsm modem(SerialAT);

// =====================================================================

// ========================[ NimBLE Bluetooth ]========================
// Import package for NimBLE Bluetooth
#include <BluetoothManager.h>

// Define Serial use for Bluetooth
#define SerialBT Serial2

// Define Bluetooth pin and baud
#define BLUETOOTH_RX 27
#define BLUETOOTH_TX 33
#define BLUETOOTH_BAUD 115200

// Create instance of NimBLE Bluetooth
BluetoothManager btManager;

// ====================================================================

// ==========================[ RFID Reader ]===========================
// Import package for RFID Reader
#include <MFRC522.h>
#include <SPI.h>

// Initial SS and RST pin of MFRC522 (RFID)
#define SS_PIN 5
#define RST_PIN 21

// Create instance of MFRC522 (RFID)
MFRC522 rfid(SS_PIN, RST_PIN);

// ====================================================================

// ======================[ OLED 172x320 1.47 Inch ]=====================
// Import package for TFT Display 172x320
#include <tft_eSPI.h>

// Import the OLED text fonts style
#include <Fonts/GFXFF/FreeSans12pt7b.h>
#include <Fonts/GFXFF/FreeSans9pt7b.h>

// Import the bitmap images for the application
#include <appIconBitmaps.h>
#include <fostiLogoBitmaps.h>
#include <idCardIconBitmaps.h>
#include <userIconBitmaps.h>

// Create instance of TFT_eSPI 172x320
TFT_eSPI display = TFT_eSPI();
// ====================================================================

// ========================[ Databases System ]========================
// Import package for Database Manager to fetch API (External)
#include <DatabaseManager.h>

// Import package for Preferences Database (Local)
#include <Preferences.h>

// Initialize API URL
String apiUrl = "https://fostipresensiapi.vercel.app";

// Initialize APN for SIMCOM A7670E
char APN[] = "internet";

// Create instance of Database Manager
DatabaseManager dbManager(modem, apiUrl);

// Create instance of Preferences Database
Preferences pref;
// ====================================================================

// ========================[ Others Settings ]=========================
#define DEBUG_MODE true

// Enum for System Options
enum MenuOption { MAIN_MENU, REGISTER, ATTENDANCE };
enum PresenceOption { NONE, PARTICIPANT, COMMITTEE, BPHI };

// ========================[ Task Handlers ]===========================
TaskHandle_t taskMainHandler = NULL;
TaskHandle_t taskRegisterHandler = NULL;
TaskHandle_t taskAttendanceHandler = NULL;
TaskHandle_t taskLoadingHandler = NULL;

// ========================[ Global Variables ]========================
MenuOption menuOption = MenuOption::MAIN_MENU; // Current main menu option
PresenceOption presenceOption =
    PresenceOption::NONE; // Current attendance option

bool showDivision = false; // Flag to show division in attendance

// Define ESP32 RTOS task method
void TaskLoadingBar(void *pvParameters);
void TaskMain(void *pvParameters);
void TaskRegister(void *pvParameters);
void TaskAttendance(void *pvParameters);

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
 * @brief Get the string representation of the presence option.
 * This function takes a PresenceOption enum value and returns
 * the corresponding string representation.
 *
 * @param option The PresenceOption enum value.
 * @return A string representation of the presence option.
 */
String getPresenceOptionName(PresenceOption option) {
    switch (option) {
    case PresenceOption::PARTICIPANT:
        return "PESERTA";
    case PresenceOption::COMMITTEE:
        return "PANITIA";
    case PresenceOption::BPHI:
        return "BPHI";
    default:
        return "UNKNOWN";
    }
}

/**
 * @brief Get the current date (YYYY-MM-DD) directly from the cellular network.
 */
String getNetworkDate() {
    int year = 0, month = 0, day = 0, hour = 0, min = 0, sec = 0;
    float tz = 0;

    // Queries AT+CCLK through TinyGSM
    if (modem.getNetworkTime(&year, &month, &day, &hour, &min, &sec, &tz)) {
        char dateBuf[16];
        snprintf(dateBuf, sizeof(dateBuf), "%04d-%02d-%02d", year, month, day);
        return String(dateBuf);
    }

    // Fallback if the tower has not broadcasted NITZ yet
    return "2026-01-01";
}

/**
 * @brief Setup function for the ESP32 system.
 * This function initializes the system components
 * and starts the main tasks.
 */
void setup() {
    // Initialize Serial for debugging
    Serial.begin(115200);

    SerialAT.setRxBufferSize(2048);
    SerialAT.begin(MODEM_BAUD, SERIAL_8N1, MODEM_RX, MODEM_TX);

    SerialBT.begin(BLUETOOTH_BAUD, SERIAL_8N1, BLUETOOTH_RX, BLUETOOTH_TX);

    // Initialize SPI for RFID Reader
    SPI.begin(18, 19, 23, SS_PIN);
    rfid.PCD_Init();

    display.init();
    display.setRotation(1);
    display.setSwapBytes(true);
    display.fillScreen(TFT_BLACK);
    display.setTextColor(TFT_WHITE);
    display.setFreeFont(&FreeSans12pt7b);

    display.pushImage(40, 25, appIconWidth, appIconHeight, appIcon);
    display.pushImage(185, 25, fostiLogoWidth, fostiLogoHeight, fostiLogo);
    delay(2000);

    xTaskCreate(TaskLoadingBar, "Loading Bar", 2048, NULL, 1,
                &taskLoadingHandler);

    // Initialize Bluetooth Manager
    btManager.begin("ESP32-PRESENCE");

    // Connect to API Server
    Serial.println("Connecting to API Server and Modem...");
    if (dbManager.begin(APN, TINYGSM_SSL_TLS1_2, "ESP32-PRESENCE", 60000)) {
        Serial.println("API Server and Modem connected!");
    } else {
        Serial.println("Failed to connect to API Server and Modem!");
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

    display.fillScreen(TFT_BLACK);
    vTaskDelete(taskLoadingHandler);

    /**
     * Create the main tasks for the ESP32 system.
     * These tasks handle the main menu, member registration,
     * and member attendance functionalities.
     */
    xTaskCreate(TaskMain, "Main Menu", 8192, NULL, 1, &taskMainHandler);
    xTaskCreate(TaskRegister, "Register Data", 8192, NULL, 1,
                &taskRegisterHandler);
    xTaskCreate(TaskAttendance, "Member Attendance", 8192, NULL, 1,
                &taskAttendanceHandler);
}

// TODO: Add register member to OLED LCD and add loading animation when registering member data to Database
/**
 * @brief Register a new member card.
 * This function handles the registration of a new member card.
 * It reads the UID from the RFID card, receives member data via
 * Bluetooth, and saves the data to the API database.
 */
void registerMember() {
    HashMap<String, String> memberData;

    // Check if a card is present and read its UID
    if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
        Serial.println("Waiting for a card...");
        return;
    }

    Serial.println();
    Serial.println("**Card Detected!**");

    // Get the UID of the card
    String memberUID = "";
    for (byte i = 0; i < rfid.uid.size; i++) {
        memberUID += rfid.uid.uidByte[i] < 0x10 ? " 0" : " ";
        memberUID += String(rfid.uid.uidByte[i], HEX);
    }
    memberUID.trim();
    memberUID.toUpperCase();

    // Send a message to the Bluetooth device indicating that a card has been detected
    String callbackData;
    JsonDocument callbackDoc;
    callbackDoc["message"] = "Member Card UID Detected!";

    JsonObject data = callbackDoc["data"].to<JsonObject>();
    data["status"] = "CARD_DETECTED";
    data["card_uid"] = memberUID;
    serializeJson(callbackDoc, callbackData);
    btManager.sendData(callbackData);

    // ====[ Wait for data from the Bluetooth device with a timeout ]====
    JsonDocument doc;
    bool dataReceived = false;
    const unsigned long TIMEOUT_MS = 60000;
    unsigned long startTime = millis();

    while (millis() - startTime < TIMEOUT_MS) {
        if (btManager.hasData()) {
            String receivedData = btManager.receiveData();
            Serial.println("Received Data: " + receivedData);

            if (receivedData.equalsIgnoreCase("Cancel")) {
                Serial.println("Registration canceled via Bluetooth.");
                rfid.PICC_HaltA();
                rfid.PCD_StopCrypto1();
                return;
            }

            DeserializationError deserializeError =
                deserializeJson(doc, receivedData);

            if (deserializeError != deserializeError.Ok) {
                Serial.print("Deserialize data failed: ");
                Serial.println(deserializeError.c_str());

                callbackData = "";
                callbackDoc.clear();
                callbackDoc["message"] = "Failed to deserialize data!";

                JsonObject data = callbackDoc["data"].to<JsonObject>();
                data["status"] = "DESERIALIZE_FAILED";

                serializeJson(callbackDoc, callbackData);
                btManager.sendData(callbackData);
                continue;
            }
            dataReceived = true;
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(
            100)); // Wait for 100 milliseconds before checking again
    }
    // ==================================================================

    // Stop reading the card
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();

    // If no data was received from the Bluetooth device within the timeout period, send a timeout message
    if (!dataReceived) {
        Serial.println("Timeout: No data received from Bluetooth!");

        callbackData = "";
        callbackDoc.clear();
        callbackDoc["message"] = "Timeout: No data received!";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["status"] = "TIMEOUT_NO_DATA";

        serializeJson(callbackDoc, callbackData);
        btManager.sendData(callbackData);
        return;
    }

    // Extract member data from the received JSON document
    String nim = doc["nim"];
    String name = doc["nama"];
    String division = doc["divisi"];

    Serial.println("NIM: " + nim);
    Serial.println("Name: " + name);
    Serial.println("Division: " + division);

    memberData.put("uid", memberUID);
    memberData.put("nim", nim);
    memberData.put("nama", name);
    memberData.put("divisi", division);

    // ====[ Send the member data to the API database ]====
    /**
     * This section sends the collected member data to the API database.
     * It uses the DatabaseManager to create a new entry in the database.
     * The response from the API is processed to determine if the operation
     * was successful or not, and appropriate messages are sent back via Bluetooth.
     */
    Serial.println("Write data to database...");

    callbackData = "";
    callbackDoc.clear();

    bool isSuccess =
        dbManager.createData("/api/mahasiswa", memberData.toJson());
    if (isSuccess) {
        Serial.println("Successfully wrote data to API database!");

        callbackDoc["message"] = "Success register member card!";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["status"] = "REGISTER_CARD_SUCCESS";
    } else {
        Serial.println("Failed to write data to API database!");

        callbackDoc["message"] = "Failed to register member card!";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["status"] = "REGISTER_CARD_FAILED";
    }

    serializeJson(callbackDoc, callbackData);
    btManager.sendData(callbackData);
    // ====================================================

    vTaskDelay(pdMS_TO_TICKS(500));
    Serial.println();
}

/**
 * @brief Show member data on the OLED display and Serial Monitor.
 * This function retrieves member data from the API database
 * using the provided UID. It displays the member's identity.
 * If the member is not found, it shows an error message on the display.
 *
 * @param UID The UID Card of the member.
 * @param showDivision If true, the member's division will be displayed.
 * @param showOnLED If true, the member data will be displayed on the OLED.
 *                  Otherwise, it will only print data to the Serial Monitor.
 *
 * @note This function uses the API to retrieve member data.
 */
void showMemberData(String UID, bool showOnLED = true) {
    // Map member data to display columns
    HashMap<String, String> column;
    column.put("uid", "Member UID");
    column.put("nim", "Member NIM");
    column.put("nama", "Member Name");
    if (showDivision)
        column.put("divisi", "Member Division");

    HashMap<String, String> memberData =
        dbManager.readData("/api/mahasiswa", UID, column);

    // Print member data to Serial Monitor
    Serial.println("=========] Member Data [=========");
    memberData.foreach ([](const String &colName, const String &colValue) {
        Serial.println(colName + ": " + colValue);
        SerialBT.println(colName + ": " + colValue);
    });
    Serial.println("=================================");

    // Print member data to OLED display
    // If showOnLED is true, display the member data on the OLED
    // Otherwise, only print to Serial Monitor
    if (showOnLED) {
        display.fillScreen(TFT_BLACK);
        display.setFreeFont(&FreeSans9pt7b);
        display.pushImage(20, 35, userIconWidth, userIconHeight, userIcon);

        // TODO: Change text size or check name lenght to prevent text overflow on OLED display
        int currentY = 60;
        int currentLine = 1;
        memberData.foreach ([&currentY, &currentLine](const String &colName,
                                                      const String &colValue) {
            display.setCursor((display.width() - 20) / 2, currentY);
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
            currentY += 20;
            currentLine++;
        });
        display.setFreeFont(&FreeSans12pt7b);
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
    Serial.println("Press 3: As a BPHI");
    Serial.println("Press 4: Manual Attendance");
    Serial.println("========================================");
    Serial.println();

    display.fillScreen(TFT_BLACK);
    display.setCursor(40, 60);
    display.print("See Presence Manager");
    display.setCursor(40, 90);
    display.print("app for Menu Selection!");
}

// TODO: Add loading animation in OLED LCD when marking member attendance to
// PostmanAPI Server
/**
 * @brief Mark attendance for a member.
 * This function to mark attendance of member by reading
 * their UID from the RFID card. It updates the attendance
 * records in the API database based on the member's UID.
 *
 * @param UID The UID Card of the member.
 * @param option The type of attendance (BPHI, Committee, or Participant).
 */
void memberAttendance(String cardUID, PresenceOption option) {
    Serial.println("Fetching member UID to database...");

    String callbackData;
    JsonDocument callbackDoc;
    callbackDoc["message"] = "Member Card UID Detected!";

    JsonObject data = callbackDoc["data"].to<JsonObject>();
    data["status"] = "CARD_DETECTED";
    data["card_uid"] = cardUID;
    serializeJson(callbackDoc, callbackData);
    btManager.sendData(callbackData);

    // ====[ Wait for data from the Bluetooth device with a timeout ]====
    JsonDocument doc;
    bool dataReceived = false;
    const unsigned long TIMEOUT_MS = 60000;
    unsigned long startTime = millis();

    while (millis() - startTime < TIMEOUT_MS) {
        if (btManager.hasData()) {
            String receivedData = btManager.receiveData();
            Serial.println("Received Data: " + receivedData);

            DeserializationError deserializeError =
                deserializeJson(doc, receivedData);

            if (deserializeError != deserializeError.Ok) {
                Serial.print("Deserialize data failed: ");
                Serial.println(deserializeError.c_str());

                callbackData = "";
                callbackDoc.clear();
                callbackDoc["message"] = "Failed to deserialize data!";

                JsonObject data = callbackDoc["data"].to<JsonObject>();
                data["status"] = "DESERIALIZE_FAILED";

                serializeJson(callbackDoc, callbackData);
                btManager.sendData(callbackData);
                continue;
            }
            dataReceived = true;
            break;
        }
        vTaskDelay(pdMS_TO_TICKS(
            100)); // Wait for 100 milliseconds before checking again
    }
    // ==================================================================

    if (!dataReceived) {
        Serial.println("Timeout: No data received from Bluetooth!");

        callbackData = "";
        callbackDoc.clear();
        callbackDoc["message"] = "Timeout: No data received!";

        JsonObject data = callbackDoc["data"].to<JsonObject>();
        data["status"] = "TIMEOUT_NO_DATA";

        serializeJson(callbackDoc, callbackData);
        btManager.sendData(callbackData);
        return;
    }

    String status = doc["data"]["status"].as<String>();
    if (status == "USER_VALID_AND_NOT_ATTENDANCE") {
        String memberId = doc["data"]["memberId"].as<String>();
        String name = doc["data"]["nama"].as<String>();
        String nim = doc["data"]["nim"].as<String>();
        String division = doc["data"]["divisi"].as<String>();

        Serial.println("Member Id: " + memberId);
        Serial.println("Name: " + name);
        Serial.println("NIM: " + nim);
        Serial.println("Division: " + division);

        HashMap<String, String> attendanceData;
        attendanceData.put("uid", cardUID);
        attendanceData.put("role", getPresenceOptionName(option));

        String currentDate = getNetworkDate();

        bool isSuccess =
            dbManager.createData("/api/log/masuk", attendanceData.toJson());

        callbackData = "";
        callbackDoc.clear();
        if (isSuccess) {
            Serial.println("Successfully wrote data to API Server!");
            Serial.printf("Member with UID %s doing Log In attendance on %s!\n",
                          cardUID, currentDate);

            callbackDoc["message"] =
                "User successfully attendence on active event!";

            JsonObject data = callbackDoc["data"].to<JsonObject>();
            data["status"] = "USER_SUCCESS_ATTENDANCE";
            data["card_uid"] = cardUID;

            serializeJson(callbackDoc, callbackData);
            btManager.sendData(callbackData);

            display.setTextColor(TFT_BLACK);
            display.setCursor((display.width() - 180) / 2,
                              (display.height() + 130) / 2);
            display.print("ID Card Detected!");
            display.setTextColor(TFT_WHITE);
            display.setCursor((display.width() - 160) / 2,
                              (display.height() + 130) / 2);
            display.print("Success Log In!");

            showMemberData(memberId);
        } else {
            Serial.println("Failed to write data to API Server!");

            callbackDoc["message"] = "User failed attendence on active event!";

            JsonObject data = callbackDoc["data"].to<JsonObject>();
            data["status"] = "USER_FAILED_ATTENDANCE";
            data["card_uid"] = cardUID;

            serializeJson(callbackDoc, callbackData);
            btManager.sendData(callbackData);

            display.setTextColor(TFT_BLACK);
            display.setCursor((display.width() - 180) / 2,
                              (display.height() + 130) / 2);
            display.print("ID Card Detected!");
            display.setTextColor(TFT_WHITE);
            display.setCursor((display.width() - 210) / 2,
                              (display.height() + 130) / 2);
            display.print("Failed to Attendance!");
        }
        return;
    } else if (status == "USER_ALREADY_ATTENDANCE_OR_EVENT_NOT_EXISTS") {
        Serial.println(
            "User already attend on active event or event not exists!");
    } else if (status == "USER_NOT_EXISTS") {
        Serial.println("User not exists in database!");
    }

    vTaskDelay(pdMS_TO_TICKS(5000));
    Serial.println();
}

// TODO: Add loading animation in OLED LCD when marking member attendance to Database and add display message in OLED LCD
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
    SerialBT.println(callbackData);

    String inputData = "";
    size_t readData = -1;

    Serial.println("===========] Manual Attendance [===========");
    Serial.println("Please enter member name and nim you want to be marked:");
    Serial.println("Note: You can type 'Cancel' to cancel the attendance.");
    Serial.println();

    SerialBT.println("======] Manual Presence [======");
    SerialBT.println("Please enter member name and nim you want to be marked:");
    SerialBT.println("You can type 'Cancel' to cancel the presence.</nl>");

    // ===================[ Prompt for Name ]===================
    Serial.print("Write Member Name: ");
    SerialBT.println("Write Member Name: ");

    // Read until newline or buffer is full
    buffer[readData] = '\0'; // Null-terminate C-string

    // Convert to Arduino String
    inputData = String(buffer);
    inputData.trim();

    // If input is Cancel or no input is received, cancel the registration
    if (inputData.equals("")) {
        Serial.println("Timeout for waiting input data! Try again later.");
        SerialBT.println(
            "</nl>Timeout for waiting input data! Try again later.</nl>");
        Serial.println();
        return;
    } else if (inputData.equalsIgnoreCase("Cancel")) {
        Serial.println("Register data has been canceled!");
        SerialBT.println("</nl>Register data has been canceled!</nl>");
        Serial.println();
        return;
    }

    String namaAnggota = inputData;
    Serial.println(namaAnggota);
    memberData.put("nama", namaAnggota);
    buffer[0] = '\0'; // clear buffer

    // ===================[ Prompt for NIM ]===================
    Serial.print("Write Member NIM: ");
    SerialBT.println("Write Member NIM: ");

    // Read until newline or buffer is full
    buffer[readData] = '\0'; // Null-terminate C-string

    // Convert to Arduino String
    inputData = String(buffer);
    inputData.trim();

    // If input is Cancel or no input is received, cancel the registration
    if (inputData.equals("")) {
        Serial.println("Timeout for waiting input data! Try again later.");
        SerialBT.println(
            "</nl>Timeout for waiting input data! Try again later.</nl>");
        Serial.println();
        return;
    } else if (inputData.equalsIgnoreCase("Cancel")) {
        Serial.println("Register data has been canceled!");
        SerialBT.println("</nl>Register data has been canceled!</nl>");
        Serial.println();
        return;
    }

    String nimAnggota = inputData;
    Serial.println(nimAnggota);
    memberData.put("nim", nimAnggota);
    buffer[0] = '\0'; // clear buffer

    // Save member attendance data to PostmanAPI database
    Serial.println("Write data to PostmanAPI database...");
    SerialBT.println("</nl>Write data to PostmanAPI database...");
    delay(500);

    String memberCardUID;
    String currentDate = getNetworkDate();

    bool success = dbManager.createData("/api/log/izin", memberData.toJson());
    if (success) {
        Serial.println("Successfully wrote data to PostmanAPI database!");
        SerialBT.println("Successfully wrote data to PostmanAPI Server!");
        delay(500);
        Serial.println();
        Serial.printf("You forced Member with UID %s to absent on %s!\n",
                      memberCardUID, currentDate);
        SerialBT.printf(
            "You forced Member with UID %s to absent on %s!</nl></nl>\n",
            memberCardUID, currentDate);
        delay(500);

        showMemberData(memberCardUID, false);
    } else {
        Serial.println("Failed to write data to PostmanAPI Server!");
        SerialBT.println("Failed to write data to PostmanAPI Server!</nl>");
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

    display.setTextColor(TFT_BLACK);
    display.setCursor((display.width() - 180) / 2,
                      (display.height() + 130) / 2);
    display.print("Tap Your ID Card!");
    display.setTextColor(TFT_WHITE);
    display.setCursor((display.width() - 180) / 2,
                      (display.height() + 130) / 2);
    display.print("ID Card Detected!");

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
    Serial.println("========================================");
    Serial.println();

    display.fillScreen(TFT_BLACK);
    display.setCursor(40, 60);
    display.print("See Presence Manager");
    display.setCursor(40, 90);
    display.print("app for Menu Selection!");
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
        int x = (display.width() - 100) / 2;
        int y = (display.height() + 120) / 2;

        if (currentLoadingDot == 0) {
            display.setTextColor(TFT_BLACK);
            display.setCursor(x, y);
            display.print("Loading....");
            display.setTextColor(TFT_WHITE);
            display.setCursor(x, y);
            display.print("Loading");
        } else if (currentLoadingDot == 1) {
            display.setTextColor(TFT_BLACK);
            display.setCursor(x, y);
            display.print("Loading");
            display.setTextColor(TFT_WHITE);
            display.setCursor(x, y);
            display.print("Loading.");
        } else if (currentLoadingDot == 2) {
            display.setTextColor(TFT_BLACK);
            display.setCursor(x, y);
            display.print("Loading.");
            display.setTextColor(TFT_WHITE);
            display.setCursor(x, y);
            display.print("Loading..");
        } else if (currentLoadingDot == 3) {
            display.setTextColor(TFT_BLACK);
            display.setCursor(x, y);
            display.print("Loading..");
            display.setTextColor(TFT_WHITE);
            display.setCursor(x, y);
            display.print("Loading...");
        } else if (currentLoadingDot == 4) {
            display.setTextColor(TFT_BLACK);
            display.setCursor(x, y);
            display.print("Loading...");
            display.setTextColor(TFT_WHITE);
            display.setCursor(x, y);
            display.print("Loading....");
            currentLoadingDot = -1;
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
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
        if (!btManager.hasData()) {
            vTaskDelay(pdMS_TO_TICKS(1000));
            continue;
        }

        String receivedData = btManager.receiveData();
        if (receivedData != "" && menuOption == MenuOption::MAIN_MENU) {
#if DEBUG_MODE
            Serial.println(receivedData);
#endif

            int options = receivedData.toInt();
            switch (options) {
            case 1:
                Serial.println("Opening register member data...");
                menuOption = MenuOption::REGISTER;

                if (taskRegisterHandler != NULL) {
                    xTaskNotifyGive(
                        taskRegisterHandler); // Notify the register task to start
                }

                ulTaskNotifyTake(
                    pdTRUE,
                    portMAX_DELAY); // Wait for the register task to complete

                showMenu();
                break;
            case 2:
                Serial.println("Opening attendance member data...");
                menuOption = MenuOption::ATTENDANCE;

                if (taskAttendanceHandler != NULL) {
                    xTaskNotifyGive(
                        taskAttendanceHandler); // Notify the attendance task to start
                }

                ulTaskNotifyTake(
                    pdTRUE,
                    portMAX_DELAY); // Wait for the attendance task to complete

                showMenu();
                break;
            default:
                Serial.println("Invalid menu option!");
            }
        }
        vTaskDelay(pdMS_TO_TICKS(500));
    }
}

/**
 * @brief Handle member registration.
 * This task runs in a loop and waits for the main menu option to be set to
 * REGISTER. When it is, calls the @ref registerMember function to register 
 * the member data.
 *
 * @param pvParameters Pointer to the task parameters (not used).
 */
void TaskRegister(void *pvParameters) {
    (void)pvParameters;

    for (;;) {
        ulTaskNotifyTake(pdTRUE,
                         portMAX_DELAY); // Wait for notification to start

        Serial.println("[Register Task] Active");

        while (menuOption == MenuOption::REGISTER) {
            if (btManager.hasData()) {
                String receivedData = btManager.receiveData();
                if (receivedData.equalsIgnoreCase("Cancel")) {
                    Serial.println(
                        "Registration canceled. Returning to main menu...");
                    break;
                }
            }

            registerMember();
            vTaskDelay(pdMS_TO_TICKS(500));
        }

        menuOption = MenuOption::MAIN_MENU;
        if (taskMainHandler != NULL) {
            xTaskNotifyGive(taskMainHandler);
        }
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
        ulTaskNotifyTake(pdTRUE,
                         portMAX_DELAY); // Wait for notification to start

        Serial.println("[Attendance Task] Active");

        while (menuOption == MenuOption::ATTENDANCE) {
            if (btManager.hasData()) {
                String receivedData = btManager.receiveData();
                if (receivedData.equalsIgnoreCase("Cancel")) {
                    if (presenceOption != PresenceOption::NONE) {
                        Serial.println("Attendance canceled. Returning to "
                                       "attendance menu...");
                        presenceOption = PresenceOption::NONE;
                    } else {
                        Serial.println("Attendance canceled. Returning to "
                                       "main menu...");
                        break;
                    }
                }

                int option = receivedData.toInt();
                switch (option) {
                case 1:
                    Serial.println("Presence member as Participant...");
                    presenceOption = PresenceOption::PARTICIPANT;
                    break;
                case 2:
                    Serial.println("Presence member as Committee...");
                    presenceOption = PresenceOption::COMMITTEE;
                    break;
                case 3:
                    Serial.println("Presence member as BPHI...");
                    presenceOption = PresenceOption::BPHI;
                    break;
                case 4:
                    Serial.println("Manual attendance member...");
                    manualAttendance();
                    break;
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
                    Serial.println(
                        "Please put member id card into RFID Reader...");

                    display.fillScreen(TFT_BLACK);
                    display.pushImage(90, 20, idCardIconWidth, idCardIconHeight,
                                      idCardIcon);
                    display.setCursor((display.width() - 180) / 2,
                                      (display.height() + 130) / 2);
                    display.print("Tap Your ID Card!");
                }
            }
            vTaskDelay(pdMS_TO_TICKS(500));
        }

        menuOption = MenuOption::MAIN_MENU;
        if (taskMainHandler != NULL) {
            xTaskNotifyGive(taskMainHandler);
        }
    }
}
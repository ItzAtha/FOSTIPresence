#include <DatabaseManager.h>
#include <credentials.h>

DatabaseManager::DatabaseManager(TinyGsm &modem, const String &url)
    : url(url), modem(modem) {}

bool DatabaseManager::begin(char *apn, ServerSSLVersion sslVersion,
                            uint32_t timeout) {
    Serial.println("Waiting for modem boot...");
    delay(1000);

    if (!waitForModem(timeout)) {
        Serial.println("Modem initialization failed.");
        return false;
    }

    Serial.println();
    Serial.println("Initializing modem...");

    if (!modem.init()) {
        Serial.println("ERROR: modem.init() failed.");
        return false;
    }

    Serial.println("Modem initialized.");

    Serial.print("Modem: ");
    Serial.println(modem.getModemName());

    Serial.println();
    Serial.println("Checking SIM...");

    SimStatus simStatus = modem.getSimStatus();
    if (simStatus != SIM_READY) {
        Serial.print("SIM is not ready. Status: ");
        Serial.println((int)simStatus);
        return false;
    }

    Serial.println("SIM ready.");

    Serial.println();
    Serial.println("Waiting for cellular network...");

    if (!modem.waitForNetwork(120000L)) {
        Serial.println("ERROR: Network registration failed.");
        return false;
    }

    Serial.println("Network registered.");

    int signal = modem.getSignalQuality();
    Serial.print("Signal quality: ");
    Serial.println(signal);

    Serial.println();
    Serial.println("Connecting to cellular data...");

    if (!modem.gprsConnect(apn)) {
        Serial.println("ERROR: GPRS connection failed.");
        return false;
    }

    Serial.println("Cellular data connected.");

    Serial.print("IP address: ");
    Serial.println(modem.localIP());

    this->sslVersion = sslVersion;
    Serial.println("Modem configured successfully.");
    return true;
}

bool DatabaseManager::end() {
    Serial.println("Ending HTTPS session...");

    modem.https_end();

    Serial.println("HTTPS session ended.");
    Serial.println("Disconnecting from cellular data...");

    if (!modem.gprsDisconnect()) {
        Serial.println("ERROR: Failed to disconnect from GPRS.");
        return false;
    }

    Serial.println("Cellular data disconnected.");
    return true;
}

bool DatabaseManager::createData(String endpoint, JsonDocument jsonData) {
    String urlString = url + endpoint;

    if (!modem.https_begin()) {
        Serial.println("ERROR: HTTPS initialization failed.");
        return false;
    }

    if (!modem.https_set_url(String(urlString), sslVersion, true)) {
        Serial.println("ERROR: Failed to configure HTTPS URL.");
        modem.https_end();
        return false;
    }

    modem.https_set_timeout(120, 30, 30);

    String jsonPayload;
    serializeJson(jsonData, jsonPayload);

    responseCode = modem.https_post_json_format(jsonPayload);
    if (responseCode > 0) {
        response = modem.https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP POST request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modem.https_end();
            return false;
        }
    } else {
        response = modem.https_body();
        Serial.print("Error on HTTP POST request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modem.https_end();
        return false;
    }

    modem.https_end();
    return true;
}

bool DatabaseManager::updateData(String endpoint, String uid,
                                 JsonDocument jsonData) {
    String urlString = url + endpoint + '/' + uid;

    if (!modem.https_begin()) {
        Serial.println("ERROR: HTTPS initialization failed.");
        return false;
    }

    if (!modem.https_set_url(String(urlString), sslVersion, true)) {
        Serial.println("ERROR: Failed to configure HTTPS URL.");
        modem.https_end();
        return false;
    }

    modem.https_set_content_type("application/json");
    modem.https_set_timeout(120, 30, 30);

    String jsonPayload;
    serializeJson(jsonData, jsonPayload);

    responseCode = modem.https_put(jsonPayload);
    if (responseCode > 0) {
        response = modem.https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP PUT request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modem.https_end();
            return false;
        }
    } else {
        response = modem.https_body();
        Serial.print("Error on HTTP PUT request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modem.https_end();
        return false;
    }

    modem.https_end();
    return true;
}

bool DatabaseManager::deleteData(String endpoint, String uid) {
    String urlString = url + endpoint + '/' + uid;

    if (!modem.https_begin()) {
        Serial.println("ERROR: HTTPS initialization failed.");
        return false;
    }

    if (!modem.https_set_url(String(urlString), sslVersion, true)) {
        Serial.println("ERROR: Failed to configure HTTPS URL.");
        modem.https_end();
        return false;
    }

    modem.https_set_content_type("application/json");
    modem.https_set_timeout(120, 30, 30);

    responseCode = modem.https_delete("");
    if (responseCode > 0) {
        response = modem.https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP DELETE request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modem.https_end();
            return false;
        }
    } else {
        response = modem.https_body();
        Serial.print("Error on HTTP DELETE request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modem.https_end();
        return false;
    }

    modem.https_end();
    return true;
}

HashMap<String, String>
DatabaseManager::readData(String endpoint, String uid,
                          HashMap<String, String> columnData) {
    HashMap<String, String> data = {};
    String urlString = url + endpoint + '/' + uid;

    if (!modem.https_begin()) {
        Serial.println("ERROR: HTTPS initialization failed.");
        return data;
    }

    if (!modem.https_set_url(String(urlString), sslVersion, true)) {
        Serial.println("ERROR: Failed to configure HTTPS URL.");
        modem.https_end();
        return data;
    }

    modem.https_set_content_type("application/json");
    modem.https_set_timeout(120, 30, 30);

    size_t bodyLength = 0;
    responseCode = modem.https_get(&bodyLength);

    if (responseCode > 0) {
        response = modem.https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP GET request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modem.https_end();
        } else {
            JsonDocument doc, filter;
            for (size_t i = 0; i < columnData.size(); ++i) {
                String key = columnData.getKeyAt(i);
                filter["data"][key] = true;
            }

            DeserializationError deserializeError = deserializeJson(
                doc, response, DeserializationOption::Filter(filter));

            if (deserializeError) {
                Serial.print("Deserialize Json failed: ");
                Serial.println(deserializeError.c_str());

                modem.https_end();
                return data;
            }

            JsonObject dataObject = doc["data"];
            for (size_t i = 0; i < columnData.size(); ++i) {
                String key = columnData.getKeyAt(i);
                if (dataObject.containsKey(key)) {
                    data.put(key, dataObject[key].as<String>());
                }
            }
        }
    } else {
        response = modem.https_body();
        Serial.print("Error on HTTP GET request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modem.https_end();
    }

    modem.https_end();
    return data;
}

bool DatabaseManager::waitForModem(uint32_t timeout = 30000) {
    Serial.println();
    Serial.println("Waiting for modem...");

    uint32_t start = millis();

    while (millis() - start < timeout) {
        delay(500);

        if (modem.testAT(3000)) {
            Serial.println("Modem responded to AT.");
            return true;
        }

        Serial.println("Waiting for modem AT response...");
    }

    Serial.println("ERROR: Modem did not respond within timeout.");
    return false;
}

bool DatabaseManager::isModemConnected() {
    if (!modem.isGprsConnected()) {
        Serial.println("ERROR: Modem is not connected to GPRS.");
        return false;
    }
    return true;
}

/**
 * @brief Gets the URL of the Database Manager.
 * This method returns the URL that was set during the initialization of the
 * DatabaseManager instance.
 *
 * @return The URL of the Database Manager.
 */
String DatabaseManager::getUrl() const { return url; }

/**
 * @brief Gets the response from the last API request.
 * This method returns the response string that was received from the last API
 * request.
 *
 * @return The response string from the last API request.
 */
String DatabaseManager::getResponse() const { return response; }

/**
 * @brief Gets the response code from the last API request.
 * This method returns the HTTP response code that was received from the last
 * API request.
 *
 * @return The HTTP response code from the last API request.
 */
int DatabaseManager::getResponseCode() const { return responseCode; }
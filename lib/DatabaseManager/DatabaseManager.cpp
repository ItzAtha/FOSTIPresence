#include <DatabaseManager.h>

DatabaseManager::DatabaseManager(const String &url, ModemManager &modem)
    : url(url), modemManager(modem) {}

bool DatabaseManager::createData(String endpoint, JsonDocument jsonData) {
    String urlString = url + endpoint;

    if (!configureRequest(urlString)) {
        Serial.println("ERROR: Failed to configure HTTPS request.");
        return false;
    }

    String jsonPayload;
    serializeJson(jsonData, jsonPayload);

    responseCode = modemManager.getModem().https_post(jsonPayload);
    if (responseCode > 0) {
        response = modemManager.getModem().https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP POST request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modemManager.getModem().https_end();
            return false;
        }
    } else {
        response = modemManager.getModem().https_body();
        Serial.print("Error on HTTP POST request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modemManager.getModem().https_end();
        return false;
    }

    modemManager.getModem().https_end();
    return true;
}

bool DatabaseManager::updateData(String endpoint, String uid,
                                 JsonDocument jsonData) {
    String urlString = url + endpoint + '/' + uid;

    if (!configureRequest(urlString)) {
        Serial.println("ERROR: Failed to configure HTTPS request.");
        return false;
    }

    String jsonPayload;
    serializeJson(jsonData, jsonPayload);

    responseCode = modemManager.getModem().https_put(jsonPayload);
    if (responseCode > 0) {
        response = modemManager.getModem().https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP PUT request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modemManager.getModem().https_end();
            return false;
        }
    } else {
        response = modemManager.getModem().https_body();
        Serial.print("Error on HTTP PUT request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modemManager.getModem().https_end();
        return false;
    }

    modemManager.getModem().https_end();
    return true;
}

bool DatabaseManager::deleteData(String endpoint, String uid) {
    String urlString = url + endpoint + '/' + uid;

    if (!configureRequest(urlString)) {
        Serial.println("ERROR: Failed to configure HTTPS request.");
        return false;
    }

    responseCode = modemManager.getModem().https_delete("");
    if (responseCode > 0) {
        response = modemManager.getModem().https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP DELETE request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modemManager.getModem().https_end();
            return false;
        }
    } else {
        response = modemManager.getModem().https_body();
        Serial.print("Error on HTTP DELETE request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modemManager.getModem().https_end();
        return false;
    }

    modemManager.getModem().https_end();
    return true;
}

HashMap<String, String>
DatabaseManager::readData(String endpoint, String uid,
                          HashMap<String, String> columnData) {
    HashMap<String, String> data = {};
    String urlString = url + endpoint + '/' + uid;

    if (!configureRequest(urlString)) {
        Serial.println("ERROR: Failed to configure HTTPS request.");
        return data;
    }

    size_t bodyLength = 0;
    responseCode = modemManager.getModem().https_get(&bodyLength);

    if (responseCode > 0) {
        response = modemManager.getModem().https_body();

        if (responseCode != HTTP_CREATED && responseCode != HTTP_OK) {
            Serial.print("Error on HTTP GET request: (");
            Serial.print(responseCode);
            Serial.print(") ");
            Serial.println(response);
            modemManager.getModem().https_end();
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

                modemManager.getModem().https_end();
                return data;
            }

            JsonObject dataObject = doc["data"];
            for (size_t i = 0; i < columnData.size(); ++i) {
                String key = columnData.getKeyAt(i);
                if (dataObject[key].is<JsonVariant>()) {
                    data.put(key, dataObject[key].as<String>());
                }
            }
        }
    } else {
        response = modemManager.getModem().https_body();
        Serial.print("Error on HTTP GET request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        modemManager.getModem().https_end();
    }

    modemManager.getModem().https_end();
    return data;
}

bool DatabaseManager::configureRequest(const String &requestUrl) {
    if (!modemManager.ensureReady()) {
        Serial.println("ERROR: Modem is not ready for communication.");
        return false;
    }

    if (!modemManager.getModem().https_begin()) {
        Serial.println("ERROR: HTTPS initialization failed.");
        return false;
    }

    if (!modemManager.getModem().https_set_url(
            requestUrl, modemManager.getSSLVersion(), true)) {
        Serial.println("ERROR: Failed to configure HTTPS URL.");
        modemManager.getModem().https_end();
        return false;
    }

    modemManager.getModem().https_set_accept_type("application/json");
    modemManager.getModem().https_set_content_type("application/json");
    modemManager.getModem().https_set_timeout(120, 30, 30);

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
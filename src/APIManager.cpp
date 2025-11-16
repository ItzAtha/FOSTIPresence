#include <APIManager.h>

/**
 * @brief Constructor for the PostmanAPI class.
 * This constructor initializes the PostmanAPI instance with a WiFiClientSecure
 * instance for secure connections and a base URL for the Postman API.
 * It sets the URL and configures the client to disable SSL certificate
 * verification for development purposes.
 *
 * @param client WiFiClientSecure instance for secure connections.
 * @param url Base URL for the Postman API.
 */
PostmanAPI::PostmanAPI(const WiFiClientSecure &client, const String &url) {
  this->url = url;
  this->client = client;
  this->client.setInsecure(); // Disable SSL certificate verification
}

/**
 * @brief Initializes the HTTP client for making requests.
 * This method sets up the HTTP client with the specified URL,
 * sends a GET request to the API, and processes the response.
 */
bool PostmanAPI::begin() {
  httpClient.begin(client, url);
  httpClient.setTimeout(10000);
  responseCode = httpClient.GET();

  if (responseCode > 0) {
    String payload = httpClient.getString();

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      JsonDocument doc;
      DeserializationError deserializeError = deserializeJson(doc, payload);
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return false;
    }

    Serial.println(payload);
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
    return false;
  }
  httpClient.end();
  return true;
}

/**
 * @brief Ends the HTTP client and disconnects from the Postman API server.
 * This method cleans up the HTTP client and WiFi client resources,
 * ensuring a proper disconnection from the Postman API server.
 */
void PostmanAPI::end() {
  Serial.println("Disconnected from PostmanAPI Server...");

  httpClient.end();
  client.stop();
  client.flush();
}

/**
 * @brief Creates new data in the Supabase database.
 * This method sends a POST request to the specified gateway
 * with the provided JSON data in the request body.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param jsonData The JSON data to be sent in the request body.
 *
 * @return True if the data was created successfully, false otherwise.
 */
bool PostmanAPI::createData(String gateway, JsonDocument jsonData) {
  String urlString = url + gateway;

  httpClient.begin(client, urlString);
  httpClient.addHeader("Content-Type", "application/json");
  httpClient.setTimeout(10000);

  String serializeString;
  serializeJson(jsonData, serializeString);
  responseCode = httpClient.POST(serializeString);

  if (responseCode > 0) {
    String payload = httpClient.getString();

    if (responseCode != HTTP_CODE_CREATED) {
      if (responseCode != HTTP_CODE_OK) {
        int start = payload.indexOf("<pre>") + 5;
        int end = payload.indexOf("</pre>");

        JsonDocument doc;
        DeserializationError deserializeError = deserializeJson(doc, payload);
        if (start != -1 && end != -1 && end > start) {
          response = payload.substring(start, end);
        } else if (deserializeError == DeserializationError::Ok) {
          response = doc["message"].as<String>();
        } else {
          response = payload;
        }

        Serial.print("Error on HTTP GET request: (");
        Serial.print(responseCode);
        Serial.print(") ");
        Serial.println(response);
        httpClient.end();
        return false;
      }
    }
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
    httpClient.end();
    return false;
  }

  httpClient.end();
  return true;
}

/**
 * @brief Updates existing data in the Supabase database.
 * This method sends an UPDATE request to the specified gateway
 * with the provided card UID and column data to be updated.
 * It retrieves the member UID associated with the card UID
 * and constructs the URL for the update request.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param cardUID The unique identifier of the card to be updated.
 * @param columnData The data to be updated, organized by column names.
 *
 * @return True if the data was updated successfully, false otherwise.
 */
bool PostmanAPI::updateData(String gateway, String cardUID,
                            HashMap<String, String> columnData) {
  String urlString = url + gateway;

  String *memberUID = getMemberByUID(gateway, cardUID);
  if (memberUID == nullptr)
    return false;

  urlString = urlString + '/' + *memberUID;

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.sendRequest("UPDATE");

  if (responseCode > 0) {
    String payload = httpClient.getString();

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      JsonDocument doc;
      DeserializationError deserializeError = deserializeJson(doc, payload);
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return false;
    }

  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
    httpClient.end();
    return false;
  }

  httpClient.end();
  return true;
}

/**
 * @brief Deletes data from the Supabase database.
 * This method sends a DELETE request to the specified gateway
 * with the provided key to identify the data to be deleted.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param key The unique identifier of the data to be deleted.
 *
 * @return True if the data was deleted successfully, false otherwise.
 */
bool PostmanAPI::deleteData(String gateway, String key) {
  String urlString = url + gateway + '/' + key;

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.sendRequest("DELETE");

  if (responseCode > 0) {
    String payload = httpClient.getString();

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      JsonDocument doc;
      DeserializationError deserializeError = deserializeJson(doc, payload);
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return false;
    }
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
    httpClient.end();
    return false;
  }

  httpClient.end();
  return true;
}

/**
 * @brief Reads data from the Supabase database.
 * This method sends a GET request to the specified gateway
 * with the provided card UID and retrieves the data associated
 * with that card. It processes the response and returns a
 * HashMap containing the relevant data.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param cardUID The unique identifier of the card to read data for.
 * @param columnData A HashMap containing column names and their corresponding
 *                   keys in the response data.
 *
 * @return A HashMap containing the retrieved data, organized by column names.
 */
HashMap<String, String>
PostmanAPI::readData(String gateway, String cardUID,
                     HashMap<String, String> columnData) {
  HashMap<String, String> data;
  String urlString = url + gateway;

  if (gateway.endsWith("mahasiswa")) {
    String *memberUID = getMemberByUID(gateway, cardUID);
    if (memberUID == nullptr)
      return data;

    urlString = urlString + '/' + *memberUID;
  }

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.GET();

  if (responseCode > 0) {
    String payload = httpClient.getString();
    JsonDocument doc;

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      DeserializationError deserializeError = deserializeJson(doc, payload);
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return data;
    }

    if (gateway.endsWith("mahasiswa")) {
      JsonDocument filter;
      filter["data"]["id"] = true;
      filter["data"]["nim"] = true;
      filter["data"]["nama"] = true;
      filter["data"]["divisi"] = true;
      filter["data"]["kartu"]["uid"] = true;
      filter["data"]["kartu"]["logs"][0]["tanggal_masuk"] = true;

      DeserializationError deserializeError =
          deserializeJson(doc, payload, DeserializationOption::Filter(filter));

      if (deserializeError) {
        Serial.print("Deserialize Json failed: ");
        Serial.println(deserializeError.c_str());

        doc.clear();
        httpClient.end();
        return data;
      }

      JsonObject objData = doc["data"];
      JsonObject objCard = objData["kartu"];
      JsonArray objLogs = objCard["logs"];

      columnData.foreach ([&data, &objData, &objCard,
                           &objLogs](const String &key, const String &value) {
        String columnName = value;
        String columnValue;

        String dataValue = objData[key].as<String>();
        String cardValue = objCard[key].as<String>();
        String logValue = objLogs.size() > 0
                              ? objLogs[objLogs.size() - 1][key].as<String>()
                              : "null";

        if (dataValue != "null") {
          columnValue = dataValue;
        } else if (cardValue != "null") {
          columnValue = cardValue;
        } else if (logValue != "null") {
          columnValue = logValue;
        }

        data.put(columnName, columnValue);
      });
    } else if (gateway.endsWith("event")) {
      JsonDocument filter;
      filter["data"][0]["id"] = true;
      filter["data"][0]["judul"] = true;
      filter["data"][0]["isActive"] = true;

      DeserializationError deserializeError =
          deserializeJson(doc, payload, DeserializationOption::Filter(filter));

      if (deserializeError) {
        Serial.print("Deserialize Json failed: ");
        Serial.println(deserializeError.c_str());

        doc.clear();
        httpClient.end();
        return data;
      }

      JsonObject objData = doc["data"][0];

      columnData.foreach (
          [&data, &objData](const String &key, const String &value) {
            String columnName = value;
            String columnValue;

            String dataValue = objData[key].as<String>();

            if (dataValue != "null") {
              columnValue = dataValue;
            }

            data.put(columnName, columnValue);
          });
    }

    httpClient.end();
    return data;
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
  }

  httpClient.end();
  return data;
}

/**
 * @brief Checks if data exists in the Supabase database.
 * This method sends a GET request to the specified gateway
 * and checks if any data exists by examining the response.
 *
 * @param gateway The API endpoint for the specific gateway.
 *
 * @return True if data exists, false otherwise.
 */
bool PostmanAPI::isDataExists(String gateway) {
  String urlString = url + gateway;

  client.setInsecure();
  if (!httpClient.begin(client,
                        "https://fostipresensiapi.vercel.app/api/event")) {
    Serial.println(".begin failed");
    return false;
  }
  Serial.println(".begin success");
  httpClient.setTimeout(20000);
  responseCode = httpClient.GET();

  Serial.println(urlString);
  Serial.println(responseCode);
  Serial.println(httpClient.getString());
  Serial.printf("HTTP code: %d, FreeHeap: %u\n", responseCode,
                ESP.getFreeHeap());

  if (responseCode > 0) {
    String payload = httpClient.getString();

    JsonDocument doc, filter;
    filter["data"][0]["id"] = true;

    DeserializationError deserializeError =
        deserializeJson(doc, payload, DeserializationOption::Filter(filter));

    if (deserializeError) {
      Serial.print("Deserialize Json failed: ");
      Serial.println(deserializeError.c_str());

      doc.clear();
      httpClient.end();
      return false;
    }

    JsonArray dataList = doc["data"];
    httpClient.end();
    return dataList.size() > 0;
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
  }

  httpClient.end();
  return false;
}

/**
 * @brief Retrieves a member's UID by their card UID.
 * This method sends a GET request to the specified gateway
 * and searches for the member associated with the provided card UID.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param cardUID The unique identifier of the card to search for.
 *
 * @return A pointer to a String containing the member ID if found, nullptr
 * otherwise.
 */
String *PostmanAPI::getMemberByUID(String gateway, String cardUID) {
  String urlString = url + gateway;

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.GET();

  if (responseCode > 0) {
    String payload = httpClient.getString();

    JsonDocument doc, filter;
    filter["data"][0]["id"] = true;
    filter["data"][0]["kartu"]["uid"] = true;

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      DeserializationError deserializeError =
          deserializeJson(doc, payload, DeserializationOption::Filter(filter));

      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return nullptr;
    }

    DeserializationError deserializeError =
        deserializeJson(doc, payload, DeserializationOption::Filter(filter));

    if (deserializeError) {
      Serial.print("Deserialize Json failed: ");
      Serial.println(deserializeError.c_str());

      doc.clear();
      httpClient.end();
      return nullptr;
    }

    JsonArray dataList = doc["data"];
    for (JsonObject data : dataList) {
      JsonObject cardData = data["kartu"];
      String memberId = data["id"];
      String memberCardUID = cardData["uid"];

      if (memberCardUID != cardUID)
        continue;

      doc.clear();
      httpClient.end();
      return new String(memberId);
    }
    doc.clear();
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
  }

  httpClient.end();
  return nullptr;
}

/**
 * @brief Retrieves a member's ID by their name.
 * This method sends a GET request to the specified gateway
 * and searches for the member associated with the provided name.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param name The name of the member to search for.
 *
 * @return A pointer to a String containing the member ID if found, nullptr
 * otherwise.
 */
String *PostmanAPI::getMemberByName(String gateway, String name) {
  String urlString = url + gateway;

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.GET();

  if (responseCode > 0) {
    String payload = httpClient.getString();

    JsonDocument doc, filter;
    filter["data"][0]["nama"] = true;
    filter["data"][0]["kartu"]["uid"] = true;

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      DeserializationError deserializeError = deserializeJson(doc, payload);
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return nullptr;
    }

    DeserializationError deserializeError =
        deserializeJson(doc, payload, DeserializationOption::Filter(filter));

    if (deserializeError) {
      Serial.print("Deserialize Json failed: ");
      Serial.println(deserializeError.c_str());
      httpClient.end();
      return nullptr;
    }

    JsonArray dataList = doc["data"];
    for (JsonObject data : dataList) {
      String memberName = data["nama"];
      JsonObject cardData = data["kartu"];
      String memberCardUID = cardData["uid"];

      if (memberName != name)
        continue;

      httpClient.end();
      return new String(memberCardUID);
    }
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
  }

  httpClient.end();
  return nullptr;
}

/**
 * @brief Retrieves an event's ID by its name.
 * This method sends a GET request to the specified gateway
 * and searches for the event associated with the provided event name.
 *
 * @param gateway The API endpoint for the specific gateway.
 * @param eventName The name of the event to search for.
 *
 * @return A pointer to a String containing the event ID if found, nullptr
 * otherwise.
 */
String *PostmanAPI::getEventByName(String gateway, String eventName) {
  String urlString = url + gateway;

  httpClient.begin(client, urlString);
  httpClient.setTimeout(10000);
  responseCode = httpClient.GET();

  if (responseCode > 0) {
    String payload = httpClient.getString();

    JsonDocument doc, filter;
    filter["data"][0]["id"] = true;
    filter["data"][0]["judul"] = true;

    if (responseCode != HTTP_CODE_OK) {
      int start = payload.indexOf("<pre>") + 5;
      int end = payload.indexOf("</pre>");

      DeserializationError deserializeError =
          deserializeJson(doc, payload, DeserializationOption::Filter(filter));
      if (start != -1 && end != -1 && end > start) {
        response = payload.substring(start, end);
      } else if (deserializeError == DeserializationError::Ok) {
        response = doc["message"].as<String>();
      } else {
        response = payload;
      }

      Serial.print("Error on HTTP GET request: (");
      Serial.print(responseCode);
      Serial.print(") ");
      Serial.println(response);
      httpClient.end();
      return nullptr;
    }

    DeserializationError deserializeError =
        deserializeJson(doc, payload, DeserializationOption::Filter(filter));

    if (deserializeError) {
      Serial.print("Deserialize Json failed: ");
      Serial.println(deserializeError.c_str());
      httpClient.end();
      return nullptr;
    }

    JsonArray dataList = doc["data"];
    for (JsonObject data : dataList) {
      String eventId = data["id"];
      String dataEventName = data["judul"];

      if (dataEventName != eventName)
        continue;

      httpClient.end();
      return new String(eventId);
    }
  } else {
    response = HTTPClient::errorToString(responseCode);
    Serial.print("Error on HTTP GET request: (");
    Serial.print(responseCode);
    Serial.print(") ");
    Serial.println(response);
  }

  httpClient.end();
  return nullptr;
}

/**
 * @brief Gets the URL of the Postman API.
 * This method returns the URL that was set during the initialization of the
 * PostmanAPI instance.
 *
 * @return The URL of the Postman API.
 */
String PostmanAPI::getUrl() const { return url; }

/**
 * @brief Gets the response from the last API request.
 * This method returns the response string that was received from the last API
 * request.
 *
 * @return The response string from the last API request.
 */
String PostmanAPI::getResponse() const { return response; }

/**
 * @brief Gets the response code from the last API request.
 * This method returns the HTTP response code that was received from the last
 * API request.
 *
 * @return The HTTP response code from the last API request.
 */
int PostmanAPI::getResponseCode() const { return responseCode; }
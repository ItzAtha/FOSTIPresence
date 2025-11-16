#ifndef APIMANAGER_H
#define APIMANAGER_H

// Import package for PostmanAPI
#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>

// Import package for Data Collections
#include <ArrayList.h>
#include <HashMap.h>

/**
 * @brief PostmanAPI class for managing API requests to the Postman API.
 * This class provides methods to interact with the Postman API for
 * CRUD operations on the Supabase database.
 * It handles creating, reading, updating, and deleting data,
 * as well as retrieving specific members and events by their identifiers.
 * It uses secure HTTP connections to ensure data integrity and security.
 */
class PostmanAPI {
  private:
  // URL of the Postman API
  String url;
  // Response from the API
  String response;
  // Response code from the API
  int responseCode;
  // HTTP Client for making requests
  HTTPClient httpClient;
  // WiFi Client for secure connections
  // This client is used for secure connections (HTTPS)
  WiFiClientSecure client;

  public:
  // Constructor of PostmanAPI class
  PostmanAPI(const WiFiClientSecure &client, const String &url);

  bool begin();
  void end();
  String getUrl() const;
  String getResponse() const;
  int getResponseCode() const;

  bool createData(String gateway, JsonDocument jsonData);
  HashMap<String, String> readData(String gateway, String cardUID,
                                   HashMap<String, String> columnData);
  bool updateData(String gateway, String cardUID,
                  HashMap<String, String> columnData);
  bool deleteData(String gateway, String key);

  bool isDataExists(String gateway);
  String *getMemberByUID(String gateway, String cardUID);
  String *getMemberByName(String gateway, String name);
  String *getEventByName(String gateway, String eventName);
};

#endif
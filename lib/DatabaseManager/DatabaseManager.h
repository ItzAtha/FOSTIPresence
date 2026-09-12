#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

// Import package for SIMCOM A7670 modem
#include <ArduinoJson.h>
#include <TinyGsmClient.h>

// Import package for Data Collections
#include <ArrayList.h>
#include <HashMap.h>

typedef enum {
    DATA_EXISTS,
    DATA_NOT_FOUND,
    DATA_DESERIALIZE_ERROR
} dataExistence_t;

typedef enum {
    HTTP_OK = 200,
    HTTP_CREATED = 201,
    HTTP_NO_CONTENT = 204,
    HTTP_BAD_REQUEST = 400,
    HTTP_UNAUTHORIZED = 401,
    HTTP_FORBIDDEN = 403,
    HTTP_NOT_FOUND = 404,
    HTTP_METHOD_NOT_ALLOWED = 405,
    HTTP_INTERNAL_SERVER_ERROR = 500
} httpResponseCode_t;

class DatabaseManager {
  private:
    // Base URL for the API
    String url;
    // Response from the API
    String response;
    // Response code from the API
    int responseCode;
    TinyGsm &modem;
    ServerSSLVersion sslVersion;

    /**
     * @brief Waits for the modem to boot and become responsive.
     *
     * This method checks if the modem is ready by sending AT commands
     * and waiting for a response. It will keep checking until the modem
     * responds or the specified timeout is reached.
     *
     * @param timeout Maximum time to wait for the modem to respond (in milliseconds).
     * @return true if the modem responded within the timeout, false otherwise.
     */
    bool waitForModem(uint32_t timeout = 30000);

  public:
    DatabaseManager(TinyGsm &modem, const String &url);

    /**
     * @brief Initializes the HTTP client for making requests.
     *
     * This method sets up the HTTP client with the specified URL,
     * sends a GET request to the API, and processes the response.
     *
     * @param apn Access Point Name for the cellular network.
     * @param sslVersion SSL version to use for secure connections.
     * @param timeout Maximum time to wait for the modem to respond (in milliseconds).
     * @return true if initialization was successful, false otherwise.
     */
    bool begin(char *apn, ServerSSLVersion sslVersion,
               uint32_t timeout = 30000);

    /**
     * @brief Cleans up and closes the HTTP client.
     *
     * This method releases any resources allocated for the HTTP client
     * and ensures that the connection is properly closed.
     *
     * @return true if cleanup was successful, false otherwise.
     */
    bool end();

    /**
     * @brief Creates new data in the database.
     *
     * This method sends a POST request to the specified endpoint
     * with the provided JSON data.
     *
     * @param endpoint The API endpoint for the specific gateway.
     * @param jsonData The JSON data to be created.
     *
     * @return True if the data was created successfully, false otherwise.
     */
    bool createData(String endpoint, JsonDocument jsonData);

    /**
     * @brief Updates existing data in the database.
     *
     * This method sends a PUT request to the specified endpoint
     * with the provided JSON data, updating the data associated
     * with the given UID.
     *
     * @param endpoint The API endpoint for the specific gateway.
     * @param uid The unique identifier of the data to be updated.
     * @param jsonData The JSON data to update the existing data.
     *
     * @return True if the data was updated successfully, false otherwise.
     */
    bool updateData(String endpoint, String uid, JsonDocument jsonData);

    /**
     * @brief Deletes data from the database.
     *
     * This method sends a DELETE request to the specified endpoint
     * to remove the data associated with the given UID.
     *
     * @param endpoint The API endpoint for the specific gateway.
     * @param uid The unique identifier of the data to be deleted.
     *
     * @return True if the data was deleted successfully, false otherwise.
     */
    bool deleteData(String endpoint, String uid);

    /**
     * @brief Reads data from the database.
     *
     * This method sends a GET request to the specified endpoint
     * to retrieve data associated with the given UID. It populates
     * the provided HashMap with the requested column data.
     *
     * @param endpoint The API endpoint for the specific gateway.
     * @param uid The unique identifier of the data to be read.
     * @param columnData A HashMap to store the retrieved column data.
     *
     * @return A HashMap containing the requested column data if successful, or an empty HashMap if not found or on error.
     */
    HashMap<String, String> readData(String endpoint, String uid,
                                     HashMap<String, String> columnData);

    /**
     * @brief Checks if the modem is connected to the cellular network.
     * This method verifies the modem's connection status to ensure that
     * it is properly connected to the GPRS network before making any API requests.
     *
     * @return true if the modem is connected, false otherwise.
     */
    bool isModemConnected();

    /**
     * @brief Gets the URL of the last request.
     *
     * @return The URL of the last request.
     */
    String getUrl() const;

    /**
     * @brief Gets the response of the last request.
     *
     * @return The response of the last request.
     */
    String getResponse() const;

    /**
     * @brief Gets the response code of the last request.
     *
     * @return The response code of the last request.
     */
    int getResponseCode() const;
};

#endif
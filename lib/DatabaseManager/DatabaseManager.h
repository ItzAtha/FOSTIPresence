#ifndef DATABASEMANAGER_H
#define DATABASEMANAGER_H

// Import package for Modem Manager to handle modem operations
#include <ModemManager.h>

// Import package for Arduino Json
#include <ArduinoJson.h>

// Import package for Data Collections
#include <ArrayList.h>
#include <HashMap.h>

/**
 * @brief Enum for data existence status.
 * This enum is used to indicate the status of data existence
 * when performing read operations from the database.
 */
typedef enum {
    // Data exists in the database
    DATA_EXISTS,
    // Data does not exist in the database
    DATA_NOT_FOUND,
    // Error occurred during data deserialization
    DATA_DESERIALIZE_ERROR
} dataExistence_t;

/**
 * @brief Enum for HTTP response codes.
 * This enum is used to represent common HTTP response codes
 * returned by the API during database operations.
 */
typedef enum {
    // Successful responses
    HTTP_OK = 200,
    // Successful creation of a resource
    HTTP_CREATED = 201,
    // Successful deletion of a resource
    HTTP_NO_CONTENT = 204,
    // Client error responses
    HTTP_BAD_REQUEST = 400,
    // Unauthorized access
    HTTP_UNAUTHORIZED = 401,
    // Forbidden access
    HTTP_FORBIDDEN = 403,
    // Resource not found
    HTTP_NOT_FOUND = 404,
    // Method not allowed
    HTTP_METHOD_NOT_ALLOWED = 405,
    // Server error responses
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

    // Reference to the ModemManager instance for modem communication
    ModemManager &modemManager;

    /**
     * @brief Configures the HTTPS request for the API.
     *
     * This method sets up the HTTPS request with the necessary
     * headers and configurations for communication with the API.
     *
     * @return True if the request was configured successfully, false otherwise.
     */
    bool configureRequest();

  public:
    /**
     * @brief Constructs a DatabaseManager instance.
     *
     * @param url The base URL for the API.
     * @param modem Reference to the ModemManager instance used for modem communication.
     */
    DatabaseManager(const String &url, ModemManager &modem)
        : url(url), modemManager(modem) {};

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
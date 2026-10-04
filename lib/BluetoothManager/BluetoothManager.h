#ifndef BLUETOOTHMANAGER_H
#define BLUETOOTHMANAGER_H

#include <Arduino.h>
#include <NimBLEDevice.h>

#include <functional>
#include <mutex>
#include <queue>

// Define the UUID for the Bluetooth service
static NimBLEUUID serviceUUID("3707a02f-16d0-4b0f-8465-540cf4f1e049");

// Define the UUID for the Bluetooth sender characteristic
static NimBLEUUID senderUUID("a29d643b-4fda-446d-b9fd-118f540a902d");
// Define the UUID for the Bluetooth receiver characteristic
static NimBLEUUID receiverUUID("d62cc1aa-931c-488d-986f-023109b1a5b7");

// Define the UUID for the Bluetooth system sender characteristic (used for system-level communication)
static NimBLEUUID systemSenderUUID("090d493b-8be6-4a3a-8841-289afcd96584");
// Define the UUID for the Bluetooth system receiver characteristic (used for system-level communication)
static NimBLEUUID systemReceiverUUID("bcb02e3f-7c78-4aae-a42d-23b3a3ee6d98");

class BluetoothManager {
  public:
    /**
     * @brief Type definition for event callback functions.
     * This type is used to define callback functions that can be registered
     * for Bluetooth connection and disconnection events.
     */
    using EventCallback = std::function<void()>;

    /**
     * @brief Constructor for the BluetoothManager class.
     */
    BluetoothManager();

    /**
     * @brief Initialize the Bluetooth module.
     * @param deviceName The name of the Bluetooth device.
     */
    void begin(String deviceName = "ESP32_Bluetooth");

    /**
     * @brief Send data over Bluetooth.
     * @param data The data to be sent as a String.
     */
    void sendData(const String &data);

    /**
     * @brief Send system-level data over Bluetooth.
     * @param data The system-level data to be sent as a String.
     */
    void systemSendData(const String &data);

    /**
     * @brief Check if there is data available to read.
     * @return true if data is available, false otherwise.
     */
    bool hasData();

    /**
     * @brief Check if there is system-level data available to read.
     * @return true if system-level data is available, false otherwise.
     */
    bool hasSystemData();

    /**
     * @brief Receive data over Bluetooth.
     * @return The received data as a String.
     */
    String receiveData();

    /**
     * @brief Receive system-level data over Bluetooth.
     * @return The received system-level data as a String.
     */
    String receiveSystemData();

    /**
     * @brief Register a callback function for connection events.
     * @param callback The callback function to be registered.
     */
    void onConnect(EventCallback callback);

    /**
     * @brief Register a callback function for disconnection events.
     * @param callback The callback function to be registered.
     */
    void onDisconnect(EventCallback callback);

  private:
    /**
     * @brief Callback functions for connection and disconnection events.
     * These are friend classes that can access the private members of BluetoothManager.
     */
    friend class BTServerCallbacks;

    /**
     * @brief Callback functions for characteristic write events.
     * This is a friend class that can access the private members of BluetoothManager.
     */
    friend class BTCharCallbacks;

    /**
     * @brief Callback functions for system-level characteristic write events.
     * This is a friend class that can access the private members of BluetoothManager.
     */
    friend class SystemBTCharCallbacks;

    /**
     * @brief Queue to hold received data.
     * This queue is used to store data received over Bluetooth.
     */
    std::queue<String> dataQueue;

    /**
     * @brief Queue to hold received system-level data.
     * This queue is used to store system-level data received over Bluetooth.
     */
    std::queue<String> systemDataQueue;

    /**
     * @brief Mutex for thread-safe access to dataQueue.
     * This mutex is used to ensure that access to the dataQueue is thread-safe.
     */
    std::mutex dataMutex;

    /**
     * @brief Mutex for thread-safe access to systemDataQueue.
     * This mutex is used to ensure that access to the systemDataQueue is thread-safe.
     */
    std::mutex systemDataMutex;

    /**
     * @brief Callback functions for connection events.
     * These functions are called when the Bluetooth connection status changes.
     */
    EventCallback onConnectCallback = nullptr;

    /**
     * @brief Callback functions for disconnection events.
     * These functions are called when the Bluetooth connection status changes.
     */
    EventCallback onDisconnectCallback = nullptr;

    /**
     * @brief Bluetooth characteristics.
     * These pointers represent the Bluetooth characteristics for sending data.
     */
    NimBLECharacteristic *pCharSender = nullptr;

    /**
     * @brief Bluetooth characteristics.
     * These pointers represent the Bluetooth characteristics for sending system-level data.
     */
    NimBLECharacteristic *pCharSystemSender = nullptr;

    /**
     * @brief Bluetooth characteristics.
     * These pointers represent the Bluetooth characteristics for receiving data.
     */
    NimBLECharacteristic *pCharReceiver = nullptr;

    /**
     * @brief Bluetooth characteristics.
     * These pointers represent the Bluetooth characteristics for receiving system-level data.
     */
    NimBLECharacteristic *pCharSystemReceiver = nullptr;
};

#endif
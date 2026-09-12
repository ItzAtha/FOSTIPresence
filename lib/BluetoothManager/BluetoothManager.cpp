#include <BluetoothManager.h>

class BTServerCallbacks : public NimBLEServerCallbacks {
  private:
    BluetoothManager *btManager;

  public:
    BTServerCallbacks(BluetoothManager *manager) : btManager(manager) {}

    void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
        Serial.println("Client connected");

        if (btManager->onConnectCallback) {
            btManager->onConnectCallback();
        }
    }

    void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo,
                      int reason) override {
        Serial.println("Client disconnected");

        if (btManager->onDisconnectCallback) {
            btManager->onDisconnectCallback();
        }
    }
};

class BTCharCallbacks : public NimBLECharacteristicCallbacks {
  private:
    BluetoothManager *btManager;

  public:
    BTCharCallbacks(BluetoothManager *manager) : btManager(manager) {}

    void onWrite(NimBLECharacteristic *pCharacteristic,
                 NimBLEConnInfo &connInfo) override {
        std::string value = pCharacteristic->getValue();

        Serial.print("Received data: ");
        Serial.println(value.c_str());
        btManager->dataQueue.push(String(value.c_str()));
    }
};

BluetoothManager::BluetoothManager() {}

void BluetoothManager::begin(String deviceName) {
    Serial.println("Initializing Bluetooth module...");
    NimBLEDevice::init(deviceName.c_str());
    NimBLEDevice::setPower(ESP_PWR_LVL_P9);

    // Create a BLE server and set the callbacks for connection and disconnection events
    NimBLEServer *pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(new BTServerCallbacks(this));
    pServer->advertiseOnDisconnect(true); // Enable advertising on disconnect

    // Create a BLE service and characteristics for sending and receiving data
    NimBLEService *pService = pServer->createService(serviceUUID);
    pCharSender = pService->createCharacteristic(
        senderUUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
    pCharSender->setCallbacks(new BTCharCallbacks(this));

    pCharReceiver = pService->createCharacteristic(
        receiverUUID, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
    pCharReceiver->setCallbacks(new BTCharCallbacks(this));

    // Start advertising the BLE service
    NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();
    NimBLEAdvertisementData advData;
    advData.setFlags(BLE_GAP_CONN_MODE_UND);
    advData.setCompleteServices(NimBLEUUID(serviceUUID));

    NimBLEAdvertisementData scanResponseData;
    scanResponseData.setName(deviceName.c_str());

    pAdvertising->addServiceUUID(serviceUUID);
    pAdvertising->setAdvertisementData(advData);
    pAdvertising->setScanResponseData(scanResponseData);

    if (pAdvertising->start()) {
        Serial.println("Advertising started successfully.");
    } else {
        Serial.println("Failed to start advertising.");
    }
}

void BluetoothManager::sendData(const String &data) {
    if (pCharSender) {
        pCharSender->setValue(data.c_str());
        pCharSender->notify();
        Serial.print("Sent data: ");
        Serial.println(data);
    } else {
        Serial.println("Error: Data characteristic not initialized.");
    }
}

bool BluetoothManager::hasData() const { return !dataQueue.empty(); }

String BluetoothManager::receiveData() {
    if (!dataQueue.empty()) {
        String data = dataQueue.front();
        dataQueue.pop();
        return data;
    }
    return "";
}
#include <ArduinoJson.h>
#include <NimBLEDevice.h>

#define SERVICE_UUID "3707a02f-16d0-4b0f-8465-540cf4f1e049"
#define CHAR_UUID_RECEIVER                                                     \
  "d62cc1aa-931c-488d-986f-023109b1a5b7" // write from phone -> ESP32
#define CHAR_UUID_MESSAGE                                                      \
  "a2f490c0-128c-43e1-baee-4bba3ffcdb3b" // notify from ESP32 -> phone as
                                         // message transmitter
#define CHAR_UUID_DATA                                                         \
  "a29d643b-4fda-446d-b9fd-118f540a902d" // notify from ESP32 -> phone as data
                                         // transmitter
#define CHAR_UUID_REALTIME_DATA                                                \
  "a1766831-fec3-4749-92f2-931d54506e94" // notify from ESP32 -> phone as
                                         // realtime data transmitter

NimBLECharacteristic *pCharData;
NimBLECharacteristic *pCharRTData;
NimBLECharacteristic *pCharMessage;
NimBLECharacteristic *pCharReceiver;

// Define the HardwareSerial object for the chosen UART
HardwareSerial ReceiverPort(1);    // Using UART1
HardwareSerial TransmitterPort(2); // Using UART2

class BTServerCallbacks : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo) override {
    Serial.print("Client connected with ");
    Serial.println(connInfo.getAddress().toString().c_str());
  }

  void onDisconnect(NimBLEServer *pServer, NimBLEConnInfo &connInfo,
                    int reason) override {
    Serial.print("Client disconnected from ");
    Serial.println(connInfo.getAddress().toString().c_str());

    TransmitterPort.println(3);
  }
};

class BTCharCallbacks : public NimBLECharacteristicCallbacks {
  void onWrite(NimBLECharacteristic *pCharacteristic,
               NimBLEConnInfo &connInfo) override {
    String receivedData = pCharacteristic->getValue();
    receivedData.trim();

    if (receivedData.isEmpty())
      return;

    Serial.print("Received data from phone: ");
    Serial.println(receivedData);
    TransmitterPort.println(receivedData);
  }
};

void setup() {
  Serial.begin(115200); // Initialize default Serial for debugging

  ReceiverPort.begin(
      115200, SERIAL_8N1, 26,
      -1); // Initialize UART1 with baud rate, data format, RX pin, TX pin
  TransmitterPort.begin(
      115200, SERIAL_8N1, -1,
      27); // Initialize UART2 with baud rate, data format, RX pin, TX pin

  NimBLEDevice::init("ESP32-IDCARD");
  NimBLEDevice::setPower(ESP_PWR_LVL_P7);

  NimBLEServer *pServer = NimBLEDevice::createServer();
  pServer->setCallbacks(new BTServerCallbacks());
  pServer->advertiseOnDisconnect(true);

  NimBLEService *pService = pServer->createService(SERVICE_UUID);

  pCharReceiver = pService->createCharacteristic(
      CHAR_UUID_RECEIVER, NIMBLE_PROPERTY::WRITE | NIMBLE_PROPERTY::WRITE_NR);
  pCharReceiver->setCallbacks(new BTCharCallbacks());

  pCharData = pService->createCharacteristic(
      CHAR_UUID_DATA, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  pCharRTData = pService->createCharacteristic(
      CHAR_UUID_REALTIME_DATA, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  pCharMessage = pService->createCharacteristic(
      CHAR_UUID_MESSAGE, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);

  if (pService->start()) {
    Serial.println("Bluetooth service started!");
  } else {
    Serial.println("Couldn't start bluetooth service!");
  }
  delay(1000);

  NimBLEAdvertising *pAdvertising = NimBLEDevice::getAdvertising();

  NimBLEAdvertisementData advData;
  advData.setFlags(BLE_GAP_CONN_MODE_UND);
  advData.setCompleteServices(NimBLEUUID(SERVICE_UUID));

  NimBLEAdvertisementData scanResponseData;
  scanResponseData.setName("ESP32-IDCARD");

  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->setAdvertisementData(advData);
  pAdvertising->setScanResponseData(scanResponseData);

  if (pAdvertising->start()) {
    Serial.println("Bluetooth advertising started!");
  } else {
    Serial.println("Couldn't start bluetooth advertising!");
  }
  Serial.println();
}

void sendBluetoothData(String messageData) {
  String rawData = messageData;
  uint8_t *encodedData;

  JsonDocument doc;
  DeserializationError deserializeError = deserializeJson(doc, rawData);

  if (!deserializeError) {
    String type = doc["dataType"];
    String data = doc["data"];

    encodedData = (uint8_t *)data.c_str();
    if (type.equalsIgnoreCase("DATA")) {
      pCharData->setValue(encodedData, data.length());
      pCharData->notify();
      Serial.println("Received data from Main ESP32: " + data);
    } else {
      pCharRTData->setValue(encodedData, data.length());
      pCharRTData->notify();
      Serial.println("Received realtime data from Main ESP32: " + data);
    }
  } else {
    encodedData = (uint8_t *)rawData.c_str();
    pCharMessage->setValue(encodedData, rawData.length());
    pCharMessage->notify();
    Serial.println("Received message from Main ESP32: " + rawData);
  }
}

void loop() {
  if (ReceiverPort.available()) { // Check if data is available on UART2
    String receivedData = ReceiverPort.readStringUntil('\n');
    if (receivedData.isEmpty())
      return;

    sendBluetoothData(receivedData);
  }
}
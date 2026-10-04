#include <ModemManager.h>

ModemManager::ModemManager(TinyGsm &modem) : modem(modem) {}

bool ModemManager::begin(char *apn, ServerSSLVersion sslVersion,
                         String userAgent, uint32_t timeout) {
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
    Serial.println("Configuring modem settings...");
    modem.setBaud(115200);
    modem.sendAT(GF("&W"));
    modem.waitResponse(1000L);

    modem.sendAT(GF("+CNMP=38"));
    modem.waitResponse(1000L);
    modem.sendAT(GF("&W"));
    modem.waitResponse(1000L);

    modem.sendAT(GF("+CSCLK=0"));
    modem.waitResponse(1000L);

    if (!waitForSim(timeout)) {
        Serial.println("ERROR: No SIM card ready.");
        return false;
    }

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

    this->apn = apn;
    this->sslVersion = sslVersion;
    modem.https_set_user_agent(userAgent);
    Serial.println("Modem configured successfully.");
    return true;
}

bool ModemManager::end() {
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

bool ModemManager::waitForModem(uint32_t timeout) {
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

bool ModemManager::waitForSim(uint32_t timeout) {
    Serial.println();
    Serial.println("Checking SIM card...");

    uint32_t start = millis();

    while (millis() - start < timeout) {
        if (modem.getSimStatus() == SIM_READY) {
            Serial.println("SIM Card ready!");
            return true;
        }

        Serial.println("SIM not ready / not detected. Retrying...");

        modem.sendAT(GF("+CFUN=0"));
        modem.waitResponse(3000L);
        delay(1000);

        modem.sendAT(GF("+CFUN=1"));
        modem.waitResponse(5000L);
        delay(2000);
    }

    Serial.println("ERROR: SIM card detection timed out.");
    return false;
}

bool ModemManager::reconnectModem(uint32_t timeout, int retryCount) {

    if (!modem.isNetworkConnected()) {
        Serial.println("Modem is not connected to the network. Attempting to "
                       "reconnect...");
        if (!modem.waitForNetwork(timeout)) {
            Serial.println("ERROR: Network registration failed.");
            return false;
        }

        Serial.println("Network re-registered.");
    }

    for (uint8_t attempt = 1; attempt <= retryCount; attempt++) {
        Serial.printf("[Cellular] GPRS connect attempt %d/%d...\n", attempt,
                      retryCount);

        modem.gprsDisconnect();
        delay(1000);

        if (modem.gprsConnect(apn)) {
            Serial.println("[Cellular] GPRS reconnected successfully.");
            Serial.print("[Cellular] New IP: ");
            Serial.println(modem.localIP());
            return true;
        }

        delay(2000);
    }

    Serial.println("[Cellular] GPRS failed. Soft-resetting modem stack...");
    modem.init();
    modem.waitForNetwork(60000L);

    if (modem.gprsConnect(apn)) {
        Serial.println("[Cellular] Recovered after modem reinit.");
        return true;
    }

    Serial.println("[Cellular] FATAL: Could not restore data connection.");
    return false;
}

bool ModemManager::ensureReady() {
    if (!modem.isGprsConnected()) {
        Serial.println("GPRS disconnected. Reconnecting before request...");
        if (!reconnectModem(30000, 5)) {
            return false;
        }
    }

    while (modem.stream.available()) {
        modem.stream.read();
    }
    return true;
}

bool ModemManager::isModemConnected() {
    if (!modem.isGprsConnected()) {
        Serial.println("ERROR: Modem is not connected to GPRS.");
        return false;
    }
    return true;
}
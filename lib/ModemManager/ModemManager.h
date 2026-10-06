#ifndef MODEMMANAGER_H
#define MODEMMANAGER_H

#include <TinyGsmClient.h>

class ModemManager {
  private:
    // Access Point Name for the cellular network
    char *apn;

    /// @brief The TinyGsm instance used for modem communication.
    TinyGsm &modem;

    /// @brief The SSL version to use for secure connections.
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

    /**
     * @brief Waits for the sim to boot and become responsive.
     *
     * This method checks if the sim is ready by sending AT commands
     * and waiting for a response. It will keep checking until the sim
     * responds or the specified timeout is reached.
     *
     * @param timeout Maximum time to wait for the modem to respond (in milliseconds).
     * @return true if the sim responded within the timeout, false otherwise.
     */
    bool waitForSim(uint32_t timeout = 30000);

    /**
     * @brief Reconnects the modem to the cellular network.
     *
     * @param timeout The maximum time to wait for reconnection.
     *
     * @return true if the modem is successfully reconnected, false otherwise.
     */
    bool reconnectModem(uint32_t timeout = 30000, int retryCount = 3);

  public:
    /**
     * @brief Constructs a ModemManager instance.
     *
     * @param modem Reference to the TinyGsm instance used for modem communication.
     */
    ModemManager(TinyGsm &modem);

    /**
     * @brief Initializes the modem with the specified APN and SSL version.
     *
     * This method sets up the modem for communication with the cellular network
     * using the provided Access Point Name (APN) and configures the SSL version
     * for secure connections.
     *
     * @param apn The Access Point Name for the cellular network.
     * @param sslVersion The SSL version to use for secure connections.
     * @param userAgent Optional user agent string for HTTP requests (default: "ESP32-A7670E").
     * @param timeout Optional timeout for modem initialization in milliseconds (default: 30000).
     *
     * @return true if initialization was successful, false otherwise.
     */
    bool begin(char *apn, ServerSSLVersion sslVersion,
               String userAgent = "ESP32-A7670E", uint32_t timeout = 30000);

    /**
     * @brief Ends the modem communication and releases resources.
     * This method stops the modem communication and cleans up any resources
     * allocated during the modem operation.
     *
     * @return true if the modem communication was successfully ended, false otherwise.
     */
    bool end();

    /**
     * @brief Ensures that the modem is ready for communication.
     *
     * This method checks if the modem is initialized and ready to send
     * and receive data. It performs necessary checks and configurations
     * to ensure that the modem is in a proper state for communication.
     *
     * @return true if the modem is ready, false otherwise.
     */
    bool ensureReady();

    /**
     * @brief Checks the data quota for the modem.
     *
     * This method queries the modem for the current data usage and quota.
     * It can be used to monitor data consumption and ensure that the
     * modem does not exceed its allocated data limits.
     *
     * @param timeout Maximum time to wait for the modem response (in milliseconds).
     * @return true if the quota check was successful, false otherwise.
     */
    bool checkQuota(const char *shortcode, const char *keyword, String &reply);

    /**
     * @brief Checks if the modem is connected to the cellular network.
     * This method verifies the modem's connection status to ensure that
     * it is properly connected to the GPRS network before making any API requests.
     *
     * @return true if the modem is connected, false otherwise.
     */
    bool isModemConnected();

    /**
     * @brief Gets a reference to the underlying TinyGsm instance.
     *
     * @return A reference to the TinyGsm instance.
     */
    TinyGsm &getModem() { return modem; }

    /**
     * @brief Gets the current SSL version used for secure connections.
     *
     * @return The current SSL version.
     */
    ServerSSLVersion getSSLVersion() { return sslVersion; }
};

#endif
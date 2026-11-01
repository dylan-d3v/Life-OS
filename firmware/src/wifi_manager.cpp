#include "wifi_manager.h"

WiFiManager::WiFiManager()
    : _ssid(WIFI_DEFAULT_SSID),
      _password(WIFI_DEFAULT_PASS),
      _hasAttemptedConnection(false),
      _lastReconnectAttempt(0) {
}

WiFiManager::~WiFiManager() {
    disconnect();
}

bool WiFiManager::connect(const char* ssid, const char* password, uint32_t timeoutMs) {
    if (ssid != nullptr && strlen(ssid) > 0) {
        _ssid = ssid;
    }
    if (password != nullptr) {
        _password = password;
    }

    if (isConnected()) {
        return true;
    }

    Serial.printf("[WIFI] Conectando a red '%s'...\n", _ssid);

    WiFi.persistent(false); // Evita escrituras innecesarias en flash
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    WiFi.begin(_ssid, _password);

    _hasAttemptedConnection = true;
    unsigned long startTime = millis();

    while (WiFi.status() != WL_CONNECTED && (millis() - startTime) < timeoutMs) {
        delay(200);
        Serial.print('.');
    }
    Serial.println();

    if (WiFi.status() == WL_CONNECTED) {
        Serial.printf("[WIFI] Conexión establecida. IP: %s (RSSI: %d dBm)\n",
                      WiFi.localIP().toString().c_str(), WiFi.RSSI());
        return true;
    } else {
        Serial.printf("[WIFI] Error al conectar. Estado: %d\n", WiFi.status());
        return false;
    }
}

void WiFiManager::disconnect() {
    if (WiFi.status() == WL_CONNECTED || _hasAttemptedConnection) {
        Serial.println(F("[WIFI] Apagando radio Wi-Fi para ahorro de energía..."));
        WiFi.disconnect(true);
        WiFi.mode(WIFI_OFF);
        _hasAttemptedConnection = false;
    }
}

bool WiFiManager::ensureConnected() {
    if (isConnected()) {
        return true;
    }

    // Intento de reconexión cada 5 segundos si se perdió la señal
    if (millis() - _lastReconnectAttempt > 5000) {
        _lastReconnectAttempt = millis();
        Serial.println(F("[WIFI] Intentando reconexión..."));
        WiFi.reconnect();
    }

    return isConnected();
}

bool WiFiManager::isConnected() const {
    return (WiFi.status() == WL_CONNECTED);
}

int WiFiManager::getRSSI() const {
    if (!isConnected()) return 0;
    return WiFi.RSSI();
}

String WiFiManager::getLocalIP() const {
    if (!isConnected()) return String("0.0.0.0");
    return WiFi.localIP().toString();
}


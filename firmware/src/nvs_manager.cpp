#include "nvs_manager.h"

const char* NvsManager::NVS_NAMESPACE = "lifeos";

NvsManager::NvsManager()
    : _isOpened(false) {
}

NvsManager::~NvsManager() {
    end();
}

bool NvsManager::begin() {
    if (_isOpened) {
        return true;
    }
    _isOpened = _prefs.begin(NVS_NAMESPACE, false);
    if (_isOpened) {
        Serial.println(F("[NVS] Almacenamiento seguro no volátil abierto correctamente."));
    } else {
        Serial.println(F("[NVS] Advertencia: No se pudo abrir el espacio de nombres NVS"));
    }
    return _isOpened;
}

void NvsManager::end() {
    if (_isOpened) {
        _prefs.end();
        _isOpened = false;
    }
}

String NvsManager::getWifiSSID() {
    if (!_isOpened) begin();
    return _prefs.getString("wifi_ssid", WIFI_DEFAULT_SSID);
}

void NvsManager::setWifiSSID(const String& ssid) {
    if (!_isOpened) begin();
    _prefs.putString("wifi_ssid", ssid);
}

String NvsManager::getWifiPass() {
    if (!_isOpened) begin();
    return _prefs.getString("wifi_pass", WIFI_DEFAULT_PASS);
}

void NvsManager::setWifiPass(const String& pass) {
    if (!_isOpened) begin();
    _prefs.putString("wifi_pass", pass);
}

String NvsManager::getGatewayUrl() {
    if (!_isOpened) begin();
    return _prefs.getString("gateway_url", LIFE_OS_GATEWAY_URL);
}

void NvsManager::setGatewayUrl(const String& url) {
    if (!_isOpened) begin();
    _prefs.putString("gateway_url", url);
}

String NvsManager::getDeviceToken() {
    if (!_isOpened) begin();
    return _prefs.getString("device_token", "");
}

void NvsManager::setDeviceToken(const String& token) {
    if (!_isOpened) begin();
    _prefs.putString("device_token", token);
}

String NvsManager::getGroqKey() {
    if (!_isOpened) begin();
    return _prefs.getString("groq_key", "");
}

void NvsManager::setGroqKey(const String& key) {
    if (!_isOpened) begin();
    _prefs.putString("groq_key", key);
}

float NvsManager::getVolume() {
    if (!_isOpened) begin();
    return _prefs.getFloat("vol", 0.85f);
}

void NvsManager::setVolume(float volume) {
    if (!_isOpened) begin();
    _prefs.putFloat("vol", volume);
}

bool NvsManager::hasWifiConfigured() {
    if (!_isOpened) begin();
    return _prefs.isKey("wifi_ssid") && _prefs.getString("wifi_ssid").length() > 0;
}

void NvsManager::factoryReset() {
    if (!_isOpened) begin();
    _prefs.clear();
    Serial.println(F("[NVS] Configuración restablecida de fábrica."));
}


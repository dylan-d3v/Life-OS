#include "kev_bridge_service.h"

KevBridgeService::KevBridgeService()
    : _gatewayUrl(LIFE_OS_GATEWAY_URL),
      _deviceToken(""),
      _lastHttpCode(0),
      _lastError("") {
}

KevBridgeService::~KevBridgeService() {
}

void KevBridgeService::configure(const String& gatewayUrl, const String& deviceToken) {
    if (gatewayUrl.length() > 0) {
        _gatewayUrl = gatewayUrl;
    }
    _deviceToken = deviceToken;
}

bool KevBridgeService::sendTextCommand(const String& userText, KevResponse& outResponse) {
    outResponse.success = false;
    outResponse.actionName = "";
    outResponse.summary = "";
    outResponse.ttsMessage = "";
    outResponse.error = "";
    _lastHttpCode = 0;
    _lastError = "";

    if (userText.isEmpty()) {
        _lastError = "Texto de usuario vacío";
        return false;
    }

    Serial.printf("[KEV-BRIDGE] Enviando comando a %s: \"%s\"\n", _gatewayUrl.c_str(), userText.c_str());

    HTTPClient http;
    http.begin(_gatewayUrl);
    http.addHeader("Content-Type", "application/json");
    if (_deviceToken.length() > 0) {
        http.addHeader("Authorization", "Bearer " + _deviceToken);
    }
    http.setTimeout(HTTP_REQUEST_TIMEOUT_MS);

    // Armar JSON del comando
    JsonDocument requestDoc;
    requestDoc["device_id"] = LIFE_OS_DEVICE_ID;
    requestDoc["text"] = userText;

    String requestJson;
    serializeJson(requestDoc, requestJson);

    _lastHttpCode = http.POST(requestJson);

    if (_lastHttpCode == HTTP_CODE_OK || _lastHttpCode == HTTP_CODE_CREATED) {
        String responsePayload = http.getString();
        http.end();

        Serial.printf("[KEV-BRIDGE] Respuesta recibida: %s\n", responsePayload.c_str());

        JsonDocument responseDoc;
        DeserializationError err = deserializeJson(responseDoc, responsePayload);
        if (err) {
            _lastError = "Error deserializando JSON de Kev: " + String(err.c_str());
            return false;
        }

        outResponse.success = responseDoc["success"] | true;
        outResponse.actionName = responseDoc["action"].as<String>();
        outResponse.summary = responseDoc["summary"].as<String>();
        outResponse.ttsMessage = responseDoc["ttsMessage"].as<String>();
        if (outResponse.ttsMessage.isEmpty()) {
            outResponse.ttsMessage = outResponse.summary;
        }

        return true;
    } else {
        _lastError = http.errorToString(_lastHttpCode);
        Serial.printf("[KEV-BRIDGE] Error HTTP %d: %s\n", _lastHttpCode, _lastError.c_str());
        http.end();
        return false;
    }
}


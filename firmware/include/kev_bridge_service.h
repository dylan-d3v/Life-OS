#pragma once

#include <Arduino.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "config.h"

struct KevResponse {
    bool success;
    String actionName;
    String summary;
    String ttsMessage;
    String error;
};

/**
 * =============================================================================
 * Kev Bridge Service - Conector con el Motor de Inteligencia TypeSafe de Life-OS
 * =============================================================================
 * Envía el texto transcrito hacia el endpoint de Kev / Companion Gateway
 * para ejecutar la acción estructurada correspondiente y obtener la confirmación
 * auditiva sintética (ttsMessage).
 */
class KevBridgeService {
public:
    KevBridgeService();
    ~KevBridgeService();

    /**
     * Configura el endpoint del Gateway / Backend de Life-OS.
     * @param gatewayUrl URL del servicio (e.g. http://192.168.1.100:8080/api/assistant/command o Edge Function HTTPS).
     * @param deviceToken Token de autenticación del dispositivo.
     */
    void configure(const String& gatewayUrl, const String& deviceToken = "");

    /**
     * Envía la instrucción de texto del usuario al motor Kev.
     * @param userText Texto transcrito por STT.
     * @param outResponse Estructura donde se almacena el resultado tipado y el ttsMessage.
     * @return true si la petición fue procesada exitosamente.
     */
    bool sendTextCommand(const String& userText, KevResponse& outResponse);

    int getLastHttpCode() const { return _lastHttpCode; }
    String getLastError() const { return _lastError; }

private:
    String _gatewayUrl;
    String _deviceToken;
    int _lastHttpCode;
    String _lastError;
};


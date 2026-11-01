#pragma once

#include <Arduino.h>
#include <Preferences.h>
#include "config.h"

/**
 * =============================================================================
 * NVS Manager - Almacenamiento Seguro No Volátil (Preferences / Flash NVS)
 * =============================================================================
 * Permite persistir y recuperar credenciales de Wi-Fi, URLs del gateway,
 * tokens del dispositivo y preferencias de usuario sin perderlas al apagar
 * o reiniciar el microcontrolador.
 */
class NvsManager {
public:
    NvsManager();
    ~NvsManager();

    /**
     * Inicializa el espacio de nombres de Preferences ("lifeos").
     * @return true si NVS se abrió correctamente.
     */
    bool begin();

    /**
     * Cierra el almacenamiento NVS.
     */
    void end();

    // Gestión de Credenciales Wi-Fi
    String getWifiSSID();
    void setWifiSSID(const String& ssid);

    String getWifiPass();
    void setWifiPass(const String& pass);

    // Configuración de Gateway y Token
    String getGatewayUrl();
    void setGatewayUrl(const String& url);

    String getDeviceToken();
    void setDeviceToken(const String& token);

    // API Key de Groq / Whisper
    String getGroqKey();
    void setGroqKey(const String& key);

    // Preferencias de Usuario
    float getVolume();
    void setVolume(float volume);

    /**
     * Comprueba si hay credenciales Wi-Fi guardadas en NVS.
     */
    bool hasWifiConfigured();

    /**
     * Restablece todos los valores a los valores por defecto del archivo config.h.
     */
    void factoryReset();

private:
    Preferences _prefs;
    bool _isOpened;

    static const char* NVS_NAMESPACE;
};


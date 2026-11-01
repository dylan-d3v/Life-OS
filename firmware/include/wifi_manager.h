#pragma once

#include <Arduino.h>
#include <WiFi.h>
#include "config.h"

/**
 * =============================================================================
 * WiFi Manager - Gestor de Conectividad Inalámbrica
 * =============================================================================
 * Maneja la conexión Wi-Fi rápida del ESP32, reconexión automática en segundo
 * plano, monitoreo de señal (RSSI) y estados de red.
 */
class WiFiManager {
public:
    WiFiManager();
    ~WiFiManager();

    /**
     * Inicia la conexión a la red Wi-Fi con tiempo límite.
     * @param ssid Nombre de la red Wi-Fi (SSID).
     * @param password Clave WPA2/WPA3 de la red.
     * @param timeoutMs Tiempo máximo de espera en milisegundos.
     * @return true si se obtuvo una dirección IP válida.
     */
    bool connect(const char* ssid = WIFI_DEFAULT_SSID, 
                 const char* password = WIFI_DEFAULT_PASS, 
                 uint32_t timeoutMs = 12000);

    /**
     * Desconecta el módulo Wi-Fi y apaga la radio para ahorro de energía en Deep Sleep.
     */
    void disconnect();

    /**
     * Verifica y restaura la conexión si se ha perdido.
     * @return true si la conexión está activa.
     */
    bool ensureConnected();

    bool isConnected() const;
    int getRSSI() const;
    String getLocalIP() const;
    const char* getSSID() const { return _ssid; }

private:
    const char* _ssid;
    const char* _password;
    bool _hasAttemptedConnection;
    unsigned long _lastReconnectAttempt;
};


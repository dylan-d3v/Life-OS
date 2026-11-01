#pragma once

#include <Arduino.h>
#include "config.h"

struct BatteryStatus {
    float voltage;       // Voltaje actual de la celda LiPo (ej: 3.85 V)
    uint8_t percentage;  // Porcentaje estimado de carga [0% a 100%]
    bool isLow;          // true si la batería está por debajo del umbral seguro (3.3V)
};

/**
 * =============================================================================
 * Power Manager - Gestión de Energía, Telemetría de Batería y Deep Sleep
 * =============================================================================
 * Controla:
 *   1. Medición de tensión de la batería LiPo por ADC con calibración de fábrica.
 *   2. Temporizador de inactividad para suspender el dispositivo automáticamente.
 *   3. Puesta en reposo ultra profundo (Deep Sleep < 20 µA) con despertar instantáneo
 *      al presionar el botón físico Push-to-Talk (EXT0 RTC Wakeup).
 */
class PowerManager {
public:
    PowerManager(uint8_t batteryPin = PIN_BATTERY_ADC, 
                 uint8_t buttonPin = PIN_BUTTON_PTT,
                 uint32_t inactivityTimeoutMs = INACTIVITY_SLEEP_MS);
    ~PowerManager();

    /**
     * Inicializa los conversores ADC y el temporizador.
     */
    void begin();

    /**
     * Lee y calcula el estado actual de la batería LiPo.
     * @return Estructura BatteryStatus con voltaje, porcentaje y estado de alerta.
     */
    BatteryStatus readBattery();

    /**
     * Reinicia el temporizador de inactividad (debe llamarse en cada interacción del usuario).
     */
    void resetInactivityTimer();

    /**
     * Comprueba si ha expirado el tiempo de inactividad configurado.
     * @return true si el dispositivo debe entrar en Deep Sleep.
     */
    bool hasInactivityExpired() const;

    /**
     * Configura el despertar por hardware en el pin del botón PTT y entra en Deep Sleep.
     */
    void enterDeepSleep();

    uint32_t getInactivityElapsedMs() const;

private:
    uint8_t _batteryPin;
    uint8_t _buttonPin;
    uint32_t _inactivityTimeoutMs;
    unsigned long _lastActivityTime;

    static uint8_t calculatePercentage(float voltage);
};


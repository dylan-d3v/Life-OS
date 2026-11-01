#include "power_manager.h"
#include <WiFi.h>

PowerManager::PowerManager(uint8_t batteryPin, uint8_t buttonPin, uint32_t inactivityTimeoutMs)
    : _batteryPin(batteryPin),
      _buttonPin(buttonPin),
      _inactivityTimeoutMs(inactivityTimeoutMs),
      _lastActivityTime(0) {
}

PowerManager::~PowerManager() {
}

void PowerManager::begin() {
    pinMode(_batteryPin, INPUT);
    analogSetPinAttenuation(_batteryPin, ADC_11db);
    resetInactivityTimer();
}

uint8_t PowerManager::calculatePercentage(float voltage) {
    if (voltage >= BATTERY_VOLTAGE_MAX) return 100;
    if (voltage <= BATTERY_VOLTAGE_MIN) return 0;

    // Aproximación lineal de la curva de descarga de litio
    float pct = ((voltage - BATTERY_VOLTAGE_MIN) / (BATTERY_VOLTAGE_MAX - BATTERY_VOLTAGE_MIN)) * 100.0f;
    if (pct < 0.0f) pct = 0.0f;
    if (pct > 100.0f) pct = 100.0f;
    return (uint8_t)pct;
}

BatteryStatus PowerManager::readBattery() {
    BatteryStatus status;
    status.voltage = 0.0f;
    status.percentage = 0;
    status.isLow = false;

    // Lectura promediada de 8 muestras para filtrar ruidos analógicos
    uint32_t sumMillivolts = 0;
    const uint8_t samples = 8;
    for (uint8_t i = 0; i < samples; i++) {
        sumMillivolts += analogReadMilliVolts(_batteryPin);
        delayMicroseconds(250);
    }
    float pinMilliVolts = (float)sumMillivolts / (float)samples;

    // Factor multiplicador del divisor resistivo (R1 + R2) / R2
    const float dividerFactor = (float)(BATTERY_R1_OHMS + BATTERY_R2_OHMS) / (float)BATTERY_R2_OHMS;
    status.voltage = (pinMilliVolts * dividerFactor) / 1000.0f;

    // Si el valor es extremadamente bajo (< 1V), el dispositivo probablemente está alimentado por USB
    if (status.voltage < 1.0f) {
        status.voltage = 4.20f; // Asume alimentación continua por USB
        status.percentage = 100;
        status.isLow = false;
        return status;
    }

    status.percentage = calculatePercentage(status.voltage);
    status.isLow = (status.voltage <= (BATTERY_VOLTAGE_MIN + 0.1f));

    return status;
}

void PowerManager::resetInactivityTimer() {
    _lastActivityTime = millis();
}

bool PowerManager::hasInactivityExpired() const {
    return (millis() - _lastActivityTime) >= _inactivityTimeoutMs;
}

uint32_t PowerManager::getInactivityElapsedMs() const {
    return (uint32_t)(millis() - _lastActivityTime);
}

void PowerManager::enterDeepSleep() {
    Serial.println(F("[POWER] Entrando en modo reposo ultra profundo (Deep Sleep)..."));
    Serial.flush();

    // 1. Apagar radio Wi-Fi
    WiFi.disconnect(true);
    WiFi.mode(WIFI_OFF);

    // 2. Esperar a que el botón se libere completamente si el usuario lo tuviese pulsado
    while (digitalRead(_buttonPin) == LOW) {
        delay(20);
    }
    delay(50); // Antirrebote final

    // 3. Configurar despertar por hardware en el pin del botón PTT (activo en nivel bajo / LOW)
    esp_sleep_enable_ext0_wakeup((gpio_num_t)_buttonPin, 0);

    // 4. Iniciar Deep Sleep (< 20 µA de consumo)
    esp_deep_sleep_start();
}


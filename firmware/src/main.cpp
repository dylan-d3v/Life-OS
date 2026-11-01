#include <Arduino.h>
#include "config.h"

/**
 * =============================================================================
 * Life-OS Pocket Assistant - Firmware Entrypoint
 * =============================================================================
 */

void printWakeupReason() {
    esp_sleep_wakeup_cause_t wakeupReason = esp_sleep_get_wakeup_cause();
    switch (wakeupReason) {
        case ESP_SLEEP_WAKEUP_EXT0:
            Serial.println(F("[POWER] Despertado por botón Push-to-Talk (RTC GPIO EXT0)"));
            break;
        case ESP_SLEEP_WAKEUP_TIMER:
            Serial.println(F("[POWER] Despertado por temporizador RTC"));
            break;
        default:
            Serial.printf("[POWER] Inicio normal / Reset (Causa: %d)\n", wakeupReason);
            break;
    }
}

void setup() {
    Serial.begin(115200);
    delay(500);

    Serial.println();
    Serial.println(F("=================================================="));
    Serial.println(F("  LIFE-OS POCKET ASSISTANT - FIRMWARE v1.0"));
    Serial.printf( "  Target: %s\n", 
#if defined(BOARD_ESP32_S3)
        "ESP32-S3"
#else
        "ESP32 Clásico (WROOM-32)"
#endif
    );
    Serial.printf( "  Frecuencia CPU: %u MHz\n", getCpuFrequencyMhz());
    Serial.printf( "  Memoria Libre: %u KB\n", ESP.getFreeHeap() / 1024);
    Serial.println(F("=================================================="));

    printWakeupReason();

    // Configuración de Pines de Control
    pinMode(PIN_BUTTON_PTT, INPUT_PULLUP);
    pinMode(PIN_LED_STATUS, OUTPUT);
    digitalWrite(PIN_LED_STATUS, LOW);

    // Parpadeo de bienvenida en LED de estado
    digitalWrite(PIN_LED_STATUS, HIGH);
    delay(100);
    digitalWrite(PIN_LED_STATUS, LOW);

    Serial.println(F("[INIT] Periféricos básicos inicializados correctamente."));
}

void loop() {
    // Si el botón PTT es presionado (activo en nivel bajo / LOW)
    if (digitalRead(PIN_BUTTON_PTT) == LOW) {
        digitalWrite(PIN_LED_STATUS, HIGH);
        Serial.println(F("[PTT] Botón presionado. Listo para capturar audio."));
        
        while (digitalRead(PIN_BUTTON_PTT) == LOW) {
            delay(10);
        }
        
        Serial.println(F("[PTT] Botón soltado. Procesando comando..."));
        digitalWrite(PIN_LED_STATUS, LOW);
    }

    delay(20);
}


#include <Arduino.h>
#include "config.h"
#include "i2s_audio_driver.h"
#include "audio_recorder.h"
#include "audio_player.h"
#include "button_manager.h"

/**
 * =============================================================================
 * Life-OS Pocket Assistant - Firmware Entrypoint
 * =============================================================================
 */

// Instancias de los controladores de hardware
I2SAudioDriver audioDriver;
AudioRecorder audioRecorder;
AudioPlayer audioPlayer;
ButtonManager pttButton(PIN_BUTTON_PTT, BUTTON_DEBOUNCE_MS);

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

    // Inicializar botón y LED
    pttButton.begin();
    pinMode(PIN_LED_STATUS, OUTPUT);
    digitalWrite(PIN_LED_STATUS, LOW);

    // 1. Inicializar amplificador I2S de salida (MAX98357A)
    if (audioPlayer.begin()) {
        audioPlayer.setVolume(0.85f);
        // Tono de bienvenida y verificación del altavoz
        audioPlayer.playTone(SystemTone::STARTUP);
    } else {
        Serial.println(F("[ERROR] No se pudo inicializar el reproductor I2S"));
    }

    // 2. Inicializar driver de micrófono I2S de entrada (INMP441)
    if (!audioDriver.initMicrophone()) {
        Serial.println(F("[ERROR] No se pudo inicializar el micrófono I2S"));
    }

    // 3. Inicializar grabador de audio (WAV)
    if (!audioRecorder.begin(&audioDriver, 2.5f)) {
        Serial.println(F("[ERROR] No se pudo asignar buffer de grabación WAV"));
    }

    Serial.println(F("[READY] Presiona y mantén presionado el botón PTT para hablar..."));
}

void loop() {
    pttButton.update();

    // Evento: Botón acaba de ser presionado (inicio de Push-to-Talk)
    if (pttButton.wasPressed()) {
        digitalWrite(PIN_LED_STATUS, HIGH);
        // Bip de confirmación acústica
        audioPlayer.playTone(SystemTone::START_LISTENING);

        Serial.println(F("[PTT] >> Botón presionado: Capturando audio..."));
        audioRecorder.startRecording();
    }

    // Mientras el botón permanezca presionado y el grabador esté activo
    if (pttButton.isPressed() && audioRecorder.isRecording()) {
        audioRecorder.recordStep();
    }

    // Evento: Botón acaba de ser soltado (fin de Push-to-Talk)
    if (pttButton.wasReleased()) {
        digitalWrite(PIN_LED_STATUS, LOW);
        audioRecorder.stopRecording();
        audioPlayer.playTone(SystemTone::STOP_LISTENING);

        Serial.printf("[PTT] << Botón soltado tras %u ms.\n", pttButton.getHoldDurationMs());

        if (audioRecorder.getWavSize() > 44) {
            Serial.printf("[AUDIO] Grabación exitosa: %u bytes (%u ms)\n",
                          (unsigned int)audioRecorder.getWavSize(),
                          (unsigned int)audioRecorder.getDurationMs());

            // Reproducción acústica local para prueba de hardware (Loopback)
            Serial.println(F("[TEST] Reproduciendo audio grabado por el altavoz..."));
            audioPlayer.playWav(audioRecorder.getWavBuffer(), audioRecorder.getWavSize());

            // Confirmación de éxito
            audioPlayer.playTone(SystemTone::SUCCESS);
        } else {
            Serial.println(F("[AUDIO] Grabación descartada (duración insuficiente)"));
            audioPlayer.playTone(SystemTone::ERROR_TONE);
        }
    }

    delay(2);
}

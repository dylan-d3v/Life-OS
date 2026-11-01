#include <Arduino.h>
#include "config.h"
#include "i2s_audio_driver.h"
#include "audio_recorder.h"
#include "audio_player.h"
#include "button_manager.h"
#include "wifi_manager.h"
#include "stt_service.h"
#include "kev_bridge_service.h"
#include "tts_service.h"

/**
 * =============================================================================
 * Life-OS Pocket Assistant - Firmware Principal
 * =============================================================================
 */

// Periféricos y Controladores de Hardware
I2SAudioDriver audioDriver;
AudioRecorder audioRecorder;
AudioPlayer audioPlayer;
ButtonManager pttButton(PIN_BUTTON_PTT, BUTTON_DEBOUNCE_MS);
WiFiManager wifiManager;

// Servicios de Red e Inteligencia
SttService sttService;
KevBridgeService kevBridge;
TtsService ttsService;

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

    // 1. Inicializar salida de audio (MAX98357A)
    if (audioPlayer.begin()) {
        audioPlayer.setVolume(0.85f);
        audioPlayer.playTone(SystemTone::STARTUP);
    }

    // 2. Inicializar entrada de micrófono (INMP441)
    audioDriver.initMicrophone();

    // 3. Inicializar buffer de grabación WAV
    audioRecorder.begin(&audioDriver, 2.5f);

    // 4. Iniciar conexión Wi-Fi rápida
    bool wifiOk = wifiManager.connect(WIFI_DEFAULT_SSID, WIFI_DEFAULT_PASS, 8000);
    if (!wifiOk) {
        Serial.println(F("[AVISO] Wi-Fi no conectada. Funcionando en modo offline/loopback"));
    }

    // 5. Configuración de servicios de backend
    // Si se cuenta con GROQ_API_KEY se puede usar directamente Whisper Cloud
    sttService.configure("", "whisper-large-v3-turbo");
    kevBridge.configure(LIFE_OS_GATEWAY_URL);
    ttsService.configure(String(LIFE_OS_GATEWAY_URL) + "/tts");

    Serial.println(F("[READY] Sistema listo. Mantén presionado PTT para hablar con Kev."));
}

void processVoiceCommand() {
    digitalWrite(PIN_LED_STATUS, HIGH);
    audioPlayer.playTone(SystemTone::PROCESSING);

    // Si no hay Wi-Fi activa, hacer reproducción loopback de prueba acústica
    if (!wifiManager.isConnected()) {
        Serial.println(F("[PIPELINE] Sin conexión Wi-Fi: Reproduciendo muestra localmente..."));
        audioPlayer.playWav(audioRecorder.getWavBuffer(), audioRecorder.getWavSize());
        audioPlayer.playTone(SystemTone::SUCCESS);
        digitalWrite(PIN_LED_STATUS, LOW);
        return;
    }

    // PASO 1: Transcripción de Audio a Texto (STT)
    Serial.println(F("[PIPELINE 1/3] Enviando audio para transcripción (STT)..."));
    String transcription = "";
    bool sttOk = false;

    // Intento con Gateway Companion o Groq directo
    sttOk = sttService.transcribeGateway(String(LIFE_OS_GATEWAY_URL) + "/stt", 
                                        audioRecorder.getWavBuffer(), 
                                        audioRecorder.getWavSize(), 
                                        transcription);

    if (!sttOk || transcription.isEmpty()) {
        Serial.printf("[PIPELINE] Falló STT: %s\n", sttService.getLastError().c_str());
        audioPlayer.playTone(SystemTone::ERROR_TONE);
        digitalWrite(PIN_LED_STATUS, LOW);
        return;
    }

    Serial.printf("[PIPELINE 2/3] Texto reconocido: \"%s\"\n", transcription.c_str());

    // PASO 2: Despacho de Intención a Kev (TypeSafe AI Engine)
    KevResponse kevResponse;
    bool kevOk = kevBridge.sendTextCommand(transcription, kevResponse);

    if (!kevOk || !kevResponse.success) {
        Serial.printf("[PIPELINE] Falló procesamiento en Kev: %s\n", kevBridge.getLastError().c_str());
        audioPlayer.playTone(SystemTone::ERROR_TONE);
        digitalWrite(PIN_LED_STATUS, LOW);
        return;
    }

    Serial.printf("[PIPELINE 3/3] Acción ejecutada: %s. TTS: \"%s\"\n",
                  kevResponse.actionName.c_str(), kevResponse.ttsMessage.c_str());

    // PASO 3: Síntesis y Reproducción de Voz (TTS)
    audioPlayer.playTone(SystemTone::SUCCESS);
    if (!kevResponse.ttsMessage.isEmpty()) {
        ttsService.speakText(kevResponse.ttsMessage, &audioPlayer);
    }

    digitalWrite(PIN_LED_STATUS, LOW);
}

void loop() {
    pttButton.update();

    // Evento: Botón presionado (Inicio de Push-to-Talk)
    if (pttButton.wasPressed()) {
        digitalWrite(PIN_LED_STATUS, HIGH);
        audioPlayer.playTone(SystemTone::START_LISTENING);
        audioRecorder.startRecording();
        Serial.println(F("[PTT] Grabando voz..."));
    }

    // Muestreo continuo mientras el botón esté presionado
    if (pttButton.isPressed() && audioRecorder.isRecording()) {
        audioRecorder.recordStep();
    }

    // Evento: Botón soltado (Fin de Push-to-Talk)
    if (pttButton.wasReleased()) {
        digitalWrite(PIN_LED_STATUS, LOW);
        audioRecorder.stopRecording();
        audioPlayer.playTone(SystemTone::STOP_LISTENING);

        if (audioRecorder.getWavSize() > 44 && audioRecorder.getDurationMs() >= 400) {
            Serial.printf("[PTT] Grabación completada (%u ms). Iniciando pipeline...\n",
                          (unsigned int)audioRecorder.getDurationMs());
            processVoiceCommand();
        } else {
            Serial.println(F("[PTT] Grabación descartada (muy corta)"));
            audioPlayer.playTone(SystemTone::ERROR_TONE);
        }
    }

    delay(2);
}

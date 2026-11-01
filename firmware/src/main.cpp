#include <Arduino.h>
#include "config.h"
#include "i2s_audio_driver.h"
#include "audio_recorder.h"
#include "audio_player.h"
#include "button_manager.h"
#include "wifi_manager.h"
#include "power_manager.h"
#include "nvs_manager.h"
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
PowerManager powerManager(PIN_BATTERY_ADC, PIN_BUTTON_PTT, INACTIVITY_SLEEP_MS);
NvsManager nvsManager;
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
    delay(400);

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

    // 1. Inicializar almacenamiento no volátil (NVS)
    nvsManager.begin();

    // 2. Inicializar botón, LED y gestor de energía
    pttButton.begin();
    pinMode(PIN_LED_STATUS, OUTPUT);
    digitalWrite(PIN_LED_STATUS, LOW);
    powerManager.begin();

    // Telemetría de batería
    BatteryStatus bat = powerManager.readBattery();
    Serial.printf("[BATERÍA] Voltaje: %.2f V (%d%% de carga)%s\n", 
                  bat.voltage, bat.percentage, bat.isLow ? " [ALERTA: BATERÍA BAJA]" : "");

    // 3. Inicializar altavoz (MAX98357A)
    if (audioPlayer.begin()) {
        audioPlayer.setVolume(nvsManager.getVolume());
        if (bat.isLow) {
            audioPlayer.playTone(SystemTone::BATTERY_LOW);
        } else {
            audioPlayer.playTone(SystemTone::STARTUP);
        }
    }

    // Si la batería es críticamente baja, proteger la celda entrando en Deep Sleep
    if (bat.voltage < (BATTERY_VOLTAGE_MIN - 0.1f) && bat.voltage > 1.5f) {
        Serial.println(F("[POWER] Batería crítica. Suspendiendo dispositivo de inmediato."));
        powerManager.enterDeepSleep();
    }

    // 4. Inicializar entrada de micrófono (INMP441)
    audioDriver.initMicrophone();

    // 5. Inicializar grabador de audio WAV
    audioRecorder.begin(&audioDriver, 2.5f);

    // 6. Conexión Wi-Fi usando credenciales de NVS o por defecto
    String ssid = nvsManager.getWifiSSID();
    String pass = nvsManager.getWifiPass();
    bool wifiOk = wifiManager.connect(ssid.c_str(), pass.c_str(), 8000);
    if (!wifiOk) {
        Serial.println(F("[AVISO] Wi-Fi no conectada. Funcionando en modo local"));
    }

    // 7. Configuración de servicios de backend
    String gatewayUrl = nvsManager.getGatewayUrl();
    String groqKey = nvsManager.getGroqKey();
    sttService.configure(groqKey, "whisper-large-v3-turbo");
    kevBridge.configure(gatewayUrl, nvsManager.getDeviceToken());
    ttsService.configure(gatewayUrl + "/tts");

    Serial.println(F("[READY] Asistente listo. Mantén presionado PTT para hablar con Kev."));
}

void processVoiceCommand() {
    digitalWrite(PIN_LED_STATUS, HIGH);
    audioPlayer.playTone(SystemTone::PROCESSING);

    // Si no hay Wi-Fi activa, hacer reproducción loopback acústica local
    if (!wifiManager.isConnected()) {
        Serial.println(F("[PIPELINE] Sin conexión Wi-Fi: Reproduciendo muestra localmente..."));
        audioPlayer.playWav(audioRecorder.getWavBuffer(), audioRecorder.getWavSize());
        audioPlayer.playTone(SystemTone::SUCCESS);
        digitalWrite(PIN_LED_STATUS, LOW);
        powerManager.resetInactivityTimer();
        return;
    }

    // PASO 1: Transcripción de Audio a Texto (STT)
    Serial.println(F("[PIPELINE 1/3] Enviando audio a STT..."));
    String transcription = "";
    bool sttOk = false;

    // Si hay Groq Key, usar Whisper directo por HTTPS; si no, usar el Gateway Companion
    if (nvsManager.getGroqKey().length() > 0) {
        sttOk = sttService.transcribeGroq(audioRecorder.getWavBuffer(), audioRecorder.getWavSize(), transcription);
    } else {
        sttOk = sttService.transcribeGateway(nvsManager.getGatewayUrl() + "/stt", 
                                            audioRecorder.getWavBuffer(), 
                                            audioRecorder.getWavSize(), 
                                            transcription);
    }

    if (!sttOk || transcription.isEmpty()) {
        Serial.printf("[PIPELINE] Falló STT: %s\n", sttService.getLastError().c_str());
        audioPlayer.playTone(SystemTone::ERROR_TONE);
        digitalWrite(PIN_LED_STATUS, LOW);
        powerManager.resetInactivityTimer();
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
        powerManager.resetInactivityTimer();
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
    powerManager.resetInactivityTimer();
}

void loop() {
    pttButton.update();

    // Evento: Botón presionado (Inicio de Push-to-Talk)
    if (pttButton.wasPressed()) {
        powerManager.resetInactivityTimer();
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
            powerManager.resetInactivityTimer();
        }
    }

    // Comprobar expiración del temporizador de inactividad -> Entrar en Deep Sleep
    if (!pttButton.isPressed() && powerManager.hasInactivityExpired()) {
        Serial.printf("[POWER] Inactividad alcanzada (%u ms). Suspendiendo...\n", 
                      powerManager.getInactivityElapsedMs());
        powerManager.enterDeepSleep();
    }

    delay(2);
}

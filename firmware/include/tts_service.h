#pragma once

#include <Arduino.h>
#include <HTTPClient.h>
#include "config.h"
#include "audio_player.h"

/**
 * =============================================================================
 * TTS Service - Cliente de Síntesis de Voz (Text-to-Speech)
 * =============================================================================
 * Descarga y reproduce la voz sintetizada correspondiente al ttsMessage
 * devuelto por Kev, enviando los datos por streaming directo al altavoz.
 */
class TtsService {
public:
    TtsService();
    ~TtsService();

    /**
     * Configura la URL base del servicio de síntesis de voz (Companion Gateway / Cloud TTS).
     * @param ttsEndpointUrl URL base (ej: http://192.168.1.100:8080/api/assistant/tts).
     */
    void configure(const String& ttsEndpointUrl);

    /**
     * Sintetiza y reproduce el texto indicado a través del altavoz I2S.
     * @param text Mensaje en español a sintetizar (ttsMessage).
     * @param player Puntero al reproductor de audio I2S.
     * @return true si la síntesis y reproducción se completaron con éxito.
     */
    bool speakText(const String& text, AudioPlayer* player);

    int getLastHttpCode() const { return _lastHttpCode; }
    String getLastError() const { return _lastError; }

private:
    String _ttsEndpointUrl;
    int _lastHttpCode;
    String _lastError;

    static String urlEncode(const String& str);
};


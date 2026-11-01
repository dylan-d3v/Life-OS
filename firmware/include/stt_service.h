#pragma once

#include <Arduino.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include "config.h"

/**
 * =============================================================================
 * STT Service - Cliente de Transcripción de Voz a Texto
 * =============================================================================
 * Envía el archivo WAV grabado por I2S mediante una petición HTTPS
 * en formato multipart/form-data hacia la API de Whisper (Groq Cloud / OpenAI)
 * o hacia un endpoint de Companion Gateway.
 */
class SttService {
public:
    SttService();
    ~SttService();

    /**
     * Configura la API Key y el modelo de transcripción.
     * @param apiKey Clave de Groq o del proveedor STT.
     * @param model Identificador del modelo (por defecto: whisper-large-v3-turbo).
     */
    void configure(const String& apiKey, const String& model = "whisper-large-v3-turbo");

    /**
     * Transcribe un archivo WAV en memoria usando Groq Cloud Whisper API.
     * @param wavData Puntero a los bytes del archivo WAV (con cabecera).
     * @param wavSize Tamaño total en bytes del buffer WAV.
     * @param outTranscription String donde se almacenará el texto transcrito.
     * @return true si la transcripción fue exitosa (código HTTP 200).
     */
    bool transcribeGroq(const uint8_t* wavData, size_t wavSize, String& outTranscription);

    /**
     * Transcribe enviando el WAV a un Companion Gateway o Supabase Edge Function local.
     */
    bool transcribeGateway(const String& gatewayUrl, const uint8_t* wavData, size_t wavSize, String& outTranscription);

    int getLastHttpCode() const { return _lastHttpCode; }
    String getLastError() const { return _lastError; }

private:
    String _apiKey;
    String _model;
    int _lastHttpCode;
    String _lastError;

    static const char* GROQ_API_HOST;
    static const uint16_t GROQ_API_PORT;
    static const char* GROQ_API_PATH;
};


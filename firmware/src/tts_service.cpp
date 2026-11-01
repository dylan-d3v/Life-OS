#include "tts_service.h"

TtsService::TtsService()
    : _ttsEndpointUrl(""),
      _lastHttpCode(0),
      _lastError("") {
}

TtsService::~TtsService() {
}

void TtsService::configure(const String& ttsEndpointUrl) {
    _ttsEndpointUrl = ttsEndpointUrl;
}

String TtsService::urlEncode(const String& str) {
    String encoded = "";
    char c;
    char code0;
    char code1;
    for (size_t i = 0; i < str.length(); i++) {
        c = str.charAt(i);
        if (isalnum(c) || c == '-' || c == '_' || c == '.' || c == '~') {
            encoded += c;
        } else if (c == ' ') {
            encoded += "%20";
        } else {
            code0 = (c >> 4) & 0xF;
            code1 = c & 0xF;
            encoded += '%';
            encoded += (char)(code0 > 9 ? code0 - 10 + 'A' : code0 + '0');
            encoded += (char)(code1 > 9 ? code1 - 10 + 'A' : code1 + '0');
        }
    }
    return encoded;
}

bool TtsService::speakText(const String& text, AudioPlayer* player) {
    _lastHttpCode = 0;
    _lastError = "";

    if (text.isEmpty() || player == nullptr) {
        _lastError = "Texto vacío o reproductor nulo";
        return false;
    }

    if (_ttsEndpointUrl.isEmpty()) {
        _lastError = "URL de TTS no configurada";
        return false;
    }

    String fullUrl = _ttsEndpointUrl;
    if (fullUrl.indexOf('?') == -1) {
        fullUrl += "?text=" + urlEncode(text);
    } else {
        fullUrl += "&text=" + urlEncode(text);
    }

    Serial.printf("[TTS] Solicitando síntesis de voz a: %s\n", fullUrl.c_str());

    HTTPClient http;
    http.begin(fullUrl);
    http.setTimeout(HTTP_REQUEST_TIMEOUT_MS);

    _lastHttpCode = http.GET();
    if (_lastHttpCode != HTTP_CODE_OK) {
        _lastError = "Error HTTP " + String(_lastHttpCode) + ": " + http.errorToString(_lastHttpCode);
        Serial.printf("[TTS] %s\n", _lastError.c_str());
        http.end();
        return false;
    }

    int contentLength = http.getSize();
    Serial.printf("[TTS] Audio recibido (%d bytes). Reproduciendo...\n", contentLength);

    if (contentLength > 44 && contentLength < 350000) {
        uint8_t* buffer = nullptr;
        if (psramFound()) {
            buffer = (uint8_t*)ps_malloc(contentLength);
        } else {
            buffer = (uint8_t*)malloc(contentLength);
        }

        if (buffer != nullptr) {
            WiFiClient* stream = http.getStreamPtr();
            int bytesRead = 0;
            unsigned long startTime = millis();

            while (http.connected() && bytesRead < contentLength && (millis() - startTime < HTTP_REQUEST_TIMEOUT_MS)) {
                size_t avail = stream->available();
                if (avail > 0) {
                    size_t toRead = (contentLength - bytesRead < (int)avail) ? (contentLength - bytesRead) : avail;
                    int readNow = stream->readBytes(buffer + bytesRead, toRead);
                    bytesRead += readNow;
                }
                delay(1);
            }

            http.end();
            bool playOk = player->playWav(buffer, bytesRead);
            free(buffer);
            return playOk;
        }
    }

    // Fallback: Si no hay suficiente RAM continua, streaming por chunks
    WiFiClient* stream = http.getStreamPtr();
    const size_t chunkSize = 512;
    uint8_t chunkBuffer[chunkSize];

    // Saltar cabecera WAV básica (primeros 44 bytes)
    if (stream->available() >= 44) {
        stream->readBytes(chunkBuffer, 44);
    }

    while (http.connected() && (stream->available() > 0 || http.getSize() > 0)) {
        size_t avail = stream->available();
        if (avail > 0) {
            size_t toRead = (avail < chunkSize) ? avail : chunkSize;
            int readBytes = stream->readBytes(chunkBuffer, toRead);
            if (readBytes > 0) {
                player->playChunk(chunkBuffer, readBytes);
            }
        }
        delay(1);
    }

    http.end();
    return true;
}


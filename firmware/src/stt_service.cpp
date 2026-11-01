#include "stt_service.h"

const char* SttService::GROQ_API_HOST = "api.groq.com";
const uint16_t SttService::GROQ_API_PORT = 443;
const char* SttService::GROQ_API_PATH = "/openai/v1/audio/transcriptions";

SttService::SttService()
    : _model("whisper-large-v3-turbo"),
      _lastHttpCode(0),
      _lastError("") {
}

SttService::~SttService() {
}

void SttService::configure(const String& apiKey, const String& model) {
    _apiKey = apiKey;
    if (model.length() > 0) {
        _model = model;
    }
}

bool SttService::transcribeGroq(const uint8_t* wavData, size_t wavSize, String& outTranscription) {
    outTranscription = "";
    _lastHttpCode = 0;
    _lastError = "";

    if (_apiKey.isEmpty()) {
        _lastError = "API Key no configurada en SttService";
        Serial.printf("[STT] Error: %s\n", _lastError.c_str());
        return false;
    }

    if (wavData == nullptr || wavSize < 44) {
        _lastError = "Buffer WAV vacío o inválido";
        Serial.printf("[STT] Error: %s\n", _lastError.c_str());
        return false;
    }

    Serial.printf("[STT] Enviando audio (%u bytes) a Groq Whisper (%s)...\n", (unsigned int)wavSize, _model.c_str());

    WiFiClientSecure client;
    client.setInsecure(); // En desarrollo/ESP32 simplifica validación de certificados TLS
    client.setTimeout(HTTP_REQUEST_TIMEOUT_MS / 1000);

    if (!client.connect(GROQ_API_HOST, GROQ_API_PORT)) {
        _lastError = "Error de conexión TCP/TLS con api.groq.com";
        Serial.printf("[STT] Error: %s\n", _lastError.c_str());
        return false;
    }

    const char* boundary = "----LifeOsBoundary7MA4YWxkTrZu0gW";

    // Construcción de los campos de texto multipart
    String head = "";
    head += String("--") + boundary + "\r\n";
    head += "Content-Disposition: form-data; name=\"model\"\r\n\r\n";
    head += _model + "\r\n";

    head += String("--") + boundary + "\r\n";
    head += "Content-Disposition: form-data; name=\"language\"\r\n\r\n";
    head += "es\r\n";

    head += String("--") + boundary + "\r\n";
    head += "Content-Disposition: form-data; name=\"response_format\"\r\n\r\n";
    head += "json\r\n";

    head += String("--") + boundary + "\r\n";
    head += "Content-Disposition: form-data; name=\"file\"; filename=\"command.wav\"\r\n";
    head += "Content-Type: audio/wav\r\n\r\n";

    String tail = String("\r\n--") + boundary + "--\r\n";

    size_t totalPayloadLength = head.length() + wavSize + tail.length();

    // Enviar cabeceras HTTP POST
    client.printf("POST %s HTTP/1.1\r\n", GROQ_API_PATH);
    client.printf("Host: %s\r\n", GROQ_API_HOST);
    client.printf("Authorization: Bearer %s\r\n", _apiKey.c_str());
    client.printf("Content-Type: multipart/form-data; boundary=%s\r\n", boundary);
    client.printf("Content-Length: %u\r\n", (unsigned int)totalPayloadLength);
    client.println("Connection: close");
    client.println();

    // Enviar primera parte del formulario
    client.print(head);

    // Enviar datos binarios del archivo WAV en bloques de 1024 bytes para estabilidad del socket
    const size_t chunkSize = 1024;
    size_t bytesSent = 0;
    while (bytesSent < wavSize) {
        size_t toSend = (wavSize - bytesSent < chunkSize) ? (wavSize - bytesSent) : chunkSize;
        size_t written = client.write(wavData + bytesSent, toSend);
        if (written == 0) {
            _lastError = "Error de socket enviando datos WAV";
            client.stop();
            return false;
        }
        bytesSent += written;
    }

    // Enviar cierre multipart
    client.print(tail);
    client.flush();

    // Leer respuesta HTTP
    unsigned long timeoutStart = millis();
    while (client.connected() && !client.available()) {
        if (millis() - timeoutStart > HTTP_REQUEST_TIMEOUT_MS) {
            _lastError = "Timeout esperando respuesta de Groq Whisper";
            client.stop();
            return false;
        }
        delay(10);
    }

    // Parsear código de estado HTTP (ej: HTTP/1.1 200 OK)
    String statusLine = client.readStringUntil('\n');
    int codeIndex = statusLine.indexOf(' ');
    if (codeIndex != -1) {
        _lastHttpCode = statusLine.substring(codeIndex + 1, codeIndex + 4).toInt();
    }

    // Saltar cabeceras HTTP hasta línea vacía
    while (client.connected()) {
        String line = client.readStringUntil('\n');
        line.trim();
        if (line.isEmpty()) {
            break;
        }
    }

    // Leer cuerpo JSON
    String responseBody = "";
    while (client.available()) {
        responseBody += (char)client.read();
    }
    client.stop();

    Serial.printf("[STT] Respuesta HTTP %d recibida: %s\n", _lastHttpCode, responseBody.c_str());

    if (_lastHttpCode != 200) {
        _lastError = "Error HTTP " + String(_lastHttpCode) + ": " + responseBody;
        return false;
    }

    // Deserializar JSON: {"text": "..."}
    JsonDocument doc;
    DeserializationError err = deserializeJson(doc, responseBody);
    if (err) {
        _lastError = "Error deserializando JSON de respuesta: " + String(err.c_str());
        return false;
    }

    if (doc["text"].is<const char*>()) {
        outTranscription = doc["text"].as<String>();
        outTranscription.trim();
        Serial.printf("[STT] Transcripción obtenida: \"%s\"\n", outTranscription.c_str());
        return true;
    } else {
        _lastError = "El campo 'text' no existe en la respuesta";
        return false;
    }
}

bool SttService::transcribeGateway(const String& gatewayUrl, const uint8_t* wavData, size_t wavSize, String& outTranscription) {
    outTranscription = "";
    _lastHttpCode = 0;
    _lastError = "";

    if (wavData == nullptr || wavSize < 44) {
        _lastError = "Buffer WAV vacío";
        return false;
    }

    HTTPClient http;
    http.begin(gatewayUrl);
    http.addHeader("Content-Type", "audio/wav");
    http.setTimeout(HTTP_REQUEST_TIMEOUT_MS);

    _lastHttpCode = http.POST((uint8_t*)wavData, wavSize);
    if (_lastHttpCode == HTTP_CODE_OK) {
        String payload = http.getString();
        JsonDocument doc;
        if (!deserializeJson(doc, payload)) {
            if (doc["text"].is<const char*>()) {
                outTranscription = doc["text"].as<String>();
                http.end();
                return true;
            }
        }
        outTranscription = payload;
        http.end();
        return true;
    } else {
        _lastError = http.errorToString(_lastHttpCode);
        http.end();
        return false;
    }
}


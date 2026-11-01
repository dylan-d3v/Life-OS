#include "audio_recorder.h"

AudioRecorder::AudioRecorder()
    : _driver(nullptr),
      _digitalGain(2.5f),
      _isRecording(false),
      _wavBuffer(nullptr),
      _maxBufferSize(0),
      _currentWavSize(0),
      _rawAudioBytes(0),
      _recordStartTime(0) {
}

AudioRecorder::~AudioRecorder() {
    clear();
}

bool AudioRecorder::begin(I2SAudioDriver* driver, float digitalGain) {
    _driver = driver;
    _digitalGain = digitalGain;

    if (_wavBuffer != nullptr) {
        clear();
    }

    size_t targetBytes = AUDIO_BUFFER_SIZE_BYTES + sizeof(WavHeader);

    if (psramFound()) {
        _wavBuffer = (uint8_t*)ps_malloc(targetBytes);
        if (_wavBuffer != nullptr) {
            _maxBufferSize = targetBytes;
            Serial.printf("[RECORDER] Buffer de audio asignado en PSRAM: %u KB (hasta %d segs)\n",
                          (unsigned int)(_maxBufferSize / 1024), AUDIO_MAX_RECORD_SECS);
            return true;
        }
    }

    // Si no hay PSRAM o falló ps_malloc, asignar en memoria interna cuidando el margen para WiFi/TLS
    size_t maxHeapAlloc = ESP.getMaxAllocHeap();
    const size_t tlsSafetyMargin = 45000; // Reserva mínima para sockets TLS / HTTPS
    if (maxHeapAlloc > tlsSafetyMargin + 32000) {
        _maxBufferSize = maxHeapAlloc - tlsSafetyMargin;
        if (_maxBufferSize > targetBytes) {
            _maxBufferSize = targetBytes;
        }
    } else {
        _maxBufferSize = 32000 + sizeof(WavHeader); // Fallback de emergencia (~1 segundo)
    }

    _wavBuffer = (uint8_t*)malloc(_maxBufferSize);
    if (_wavBuffer == nullptr) {
        Serial.printf("[RECORDER] Error: No se pudo asignar buffer de audio (%u bytes libres)\n", maxHeapAlloc);
        return false;
    }

    uint32_t capacitySecs = (_maxBufferSize - sizeof(WavHeader)) / (AUDIO_SAMPLE_RATE * (AUDIO_BITS_PER_SAMPLE / 8));
    Serial.printf("[RECORDER] Buffer asignado en RAM interna: %u KB (~%u segs de voz)\n",
                  (unsigned int)(_maxBufferSize / 1024), (unsigned int)capacitySecs);

    return true;
}

void AudioRecorder::populateWavHeader(WavHeader& header, uint32_t sampleRate, uint16_t bitsPerSample, uint16_t channels, uint32_t dataBytes) {
    memcpy(header.riffTag, "RIFF", 4);
    header.riffLength = 36 + dataBytes;
    memcpy(header.waveTag, "WAVE", 4);

    memcpy(header.fmtTag, "fmt ", 4);
    header.fmtLength = 16;
    header.audioFormat = 1; // PCM
    header.numChannels = channels;
    header.sampleRate = sampleRate;
    header.byteRate = sampleRate * channels * (bitsPerSample / 8);
    header.blockAlign = channels * (bitsPerSample / 8);
    header.bitsPerSample = bitsPerSample;

    memcpy(header.dataTag, "data", 4);
    header.dataLength = dataBytes;
}

bool AudioRecorder::startRecording() {
    if (_driver == nullptr || !_driver->isInitialized() || _wavBuffer == nullptr) {
        Serial.println(F("[RECORDER] Error: Grabador o driver I2S no inicializado"));
        return false;
    }

    _driver->clearDmaBuffer();
    _rawAudioBytes = 0;
    _currentWavSize = sizeof(WavHeader);
    _recordStartTime = millis();
    _isRecording = true;

    // Inicializa la cabecera WAV provisional
    WavHeader header;
    populateWavHeader(header, AUDIO_SAMPLE_RATE, AUDIO_BITS_PER_SAMPLE, AUDIO_CHANNELS, 0);
    memcpy(_wavBuffer, &header, sizeof(WavHeader));

    Serial.println(F("[RECORDER] Grabación iniciada..."));
    return true;
}

bool AudioRecorder::recordStep() {
    if (!_isRecording || _driver == nullptr) {
        return false;
    }

    // Bloque de lectura de 512 muestras (1024 bytes)
    const size_t chunkSizeSamples = 512;
    const size_t chunkSizeBytes = chunkSizeSamples * sizeof(int16_t);

    // Verificar si queda espacio suficiente en el buffer
    if ((sizeof(WavHeader) + _rawAudioBytes + chunkSizeBytes) > _maxBufferSize) {
        Serial.println(F("[RECORDER] Advertencia: Buffer de audio lleno, finalizando grabación."));
        stopRecording();
        return false;
    }

    int16_t sampleChunk[chunkSizeSamples];
    size_t bytesRead = 0;

    bool ok = _driver->readSamples(sampleChunk, chunkSizeBytes, &bytesRead, pdMS_TO_TICKS(100));
    if (ok && bytesRead > 0) {
        size_t samplesRead = bytesRead / sizeof(int16_t);
        // Amplificación por software
        I2SAudioDriver::applyDigitalGain(sampleChunk, samplesRead, _digitalGain);

        // Copia al buffer principal de salida
        memcpy(_wavBuffer + sizeof(WavHeader) + _rawAudioBytes, sampleChunk, bytesRead);
        _rawAudioBytes += bytesRead;
        return true;
    }

    return false;
}

void AudioRecorder::stopRecording() {
    if (!_isRecording) {
        return;
    }

    _isRecording = false;

    // Actualiza los tamaños reales en la cabecera WAV definitiva
    WavHeader* header = (WavHeader*)_wavBuffer;
    header->riffLength = 36 + _rawAudioBytes;
    header->dataLength = _rawAudioBytes;
    _currentWavSize = sizeof(WavHeader) + _rawAudioBytes;

    uint32_t durationMs = getDurationMs();
    Serial.printf("[RECORDER] Grabación finalizada. Total: %u bytes (%u ms, %u muestras)\n",
                  (unsigned int)_currentWavSize, (unsigned int)durationMs, (unsigned int)(_rawAudioBytes / sizeof(int16_t)));
}

uint32_t AudioRecorder::getDurationMs() const {
    if (_rawAudioBytes == 0) {
        return 0;
    }
    uint32_t bytesPerSec = AUDIO_SAMPLE_RATE * AUDIO_CHANNELS * (AUDIO_BITS_PER_SAMPLE / 8);
    return (uint32_t)(((uint64_t)_rawAudioBytes * 1000) / bytesPerSec);
}

void AudioRecorder::clear() {
    _isRecording = false;
    if (_wavBuffer != nullptr) {
        free(_wavBuffer);
        _wavBuffer = nullptr;
    }
    _maxBufferSize = 0;
    _currentWavSize = 0;
    _rawAudioBytes = 0;
}


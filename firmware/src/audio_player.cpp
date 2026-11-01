#include "audio_player.h"
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

AudioPlayer::AudioPlayer()
    : _isInitialized(false),
      _i2sPort(I2S_SPK_PORT),
      _currentSampleRate(AUDIO_SAMPLE_RATE),
      _masterVolume(0.8f) {
}

AudioPlayer::~AudioPlayer() {
    stop();
}

bool AudioPlayer::begin() {
    if (_isInitialized) {
        return true;
    }

    Serial.println(F("[I2S-SPK] Inicializando amplificador MAX98357A en I2S1..."));

    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
        .sample_rate = _currentSampleRate,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT, // Estéreo estándar para decodificación MAX98357A
        .communication_format = (i2s_comm_format_t)(I2S_COMM_FORMAT_STAND_I2S),
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = 6,
        .dma_buf_len = 512,
        .use_apll = false,
        .tx_desc_auto_clear = true, // Limpieza automática del buffer para evitar zumbidos residuales
        .fixed_mclk = 0
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_SPK_BCLK_PIN,
        .ws_io_num = I2S_SPK_LRC_PIN,
        .data_out_num = I2S_SPK_DIN_PIN,
        .data_in_num = I2S_PIN_NO_CHANGE
    };

    esp_err_t err = i2s_driver_install(_i2sPort, &i2s_config, 0, NULL);
    if (err != ESP_OK) {
        Serial.printf("[I2S-SPK] Error instalando driver de salida I2S: 0x%x\n", err);
        return false;
    }

    err = i2s_set_pin(_i2sPort, &pin_config);
    if (err != ESP_OK) {
        Serial.printf("[I2S-SPK] Error configurando pines del altavoz: 0x%x\n", err);
        i2s_driver_uninstall(_i2sPort);
        return false;
    }

    i2s_zero_dma_buffer(_i2sPort);
    _isInitialized = true;

    Serial.printf("[I2S-SPK] Amplificador listo (BCLK=%d, LRC=%d, DIN=%d, Vol=%d%%)\n",
                  I2S_SPK_BCLK_PIN, I2S_SPK_LRC_PIN, I2S_SPK_DIN_PIN, (int)(_masterVolume * 100));
    return true;
}

void AudioPlayer::stop() {
    if (_isInitialized) {
        i2s_zero_dma_buffer(_i2sPort);
        i2s_driver_uninstall(_i2sPort);
        _isInitialized = false;
        Serial.println(F("[I2S-SPK] Driver de salida desinstalado."));
    }
}

void AudioPlayer::setVolume(float volume) {
    if (volume < 0.0f) volume = 0.0f;
    if (volume > 1.0f) volume = 1.0f;
    _masterVolume = volume;
}

bool AudioPlayer::setSampleRate(uint32_t sampleRate) {
    if (!_isInitialized || sampleRate == 0) {
        return false;
    }
    if (_currentSampleRate == sampleRate) {
        return true;
    }

    esp_err_t err = i2s_set_clk(_i2sPort, sampleRate, I2S_BITS_PER_SAMPLE_16BIT, I2S_CHANNEL_STEREO);
    if (err == ESP_OK) {
        _currentSampleRate = sampleRate;
        return true;
    }
    return false;
}

void AudioPlayer::playSineWave(float frequencyHz, uint32_t durationMs, float volume) {
    if (!_isInitialized) {
        return;
    }

    setSampleRate(16000);
    const uint32_t sampleRate = 16000;
    const size_t totalFrames = (sampleRate * durationMs) / 1000;
    const size_t bufferFrames = 256;
    
    // Cada frame estéreo son 2 muestras de 16-bit (4 bytes)
    int16_t stereoBuffer[bufferFrames * 2];
    float effectiveVol = volume * _masterVolume;
    float phase = 0.0f;
    float phaseIncrement = (2.0f * (float)M_PI * frequencyHz) / (float)sampleRate;

    size_t framesRemaining = totalFrames;
    while (framesRemaining > 0) {
        size_t framesInChunk = (framesRemaining < bufferFrames) ? framesRemaining : bufferFrames;

        for (size_t i = 0; i < framesInChunk; i++) {
            int16_t sample = (int16_t)(sinf(phase) * 32767.0f * effectiveVol);
            stereoBuffer[i * 2] = sample;     // Canal Izquierdo
            stereoBuffer[i * 2 + 1] = sample; // Canal Derecho
            phase += phaseIncrement;
            if (phase >= 2.0f * (float)M_PI) {
                phase -= 2.0f * (float)M_PI;
            }
        }

        size_t bytesWritten = 0;
        i2s_write(_i2sPort, (const char*)stereoBuffer, framesInChunk * sizeof(int16_t) * 2, &bytesWritten, portMAX_DELAY);
        framesRemaining -= framesInChunk;
    }

    i2s_zero_dma_buffer(_i2sPort);
}

void AudioPlayer::playTone(SystemTone tone) {
    switch (tone) {
        case SystemTone::STARTUP:
            // Tono amigable de bienvenida (Do5 -> Sol5)
            playSineWave(523.25f, 90, 0.4f);
            delay(30);
            playSineWave(783.99f, 140, 0.5f);
            break;

        case SystemTone::START_LISTENING:
            // Bip agudo corto indicando que el micrófono está abierto
            playSineWave(880.00f, 70, 0.45f);
            break;

        case SystemTone::STOP_LISTENING:
            // Bip más grave indicando fin de grabación
            playSineWave(440.00f, 70, 0.40f);
            break;

        case SystemTone::PROCESSING:
            // Pulso suave
            playSineWave(659.25f, 50, 0.30f);
            break;

        case SystemTone::SUCCESS:
            // Arpegio mayor ascendente (Do5 -> Mi5 -> Sol5)
            playSineWave(523.25f, 60, 0.40f);
            delay(15);
            playSineWave(659.25f, 60, 0.45f);
            delay(15);
            playSineWave(783.99f, 130, 0.55f);
            break;

        case SystemTone::ERROR_TONE:
            // Tono descendente de error
            playSineWave(440.00f, 90, 0.50f);
            delay(20);
            playSineWave(329.63f, 160, 0.55f);
            break;

        case SystemTone::BATTERY_LOW:
            // Tres bips rápidos de advertencia
            for (int i = 0; i < 3; i++) {
                playSineWave(329.63f, 50, 0.6f);
                delay(50);
            }
            break;
    }
}

size_t AudioPlayer::playChunk(const uint8_t* pcmData, size_t bytesToWrite) {
    if (!_isInitialized || pcmData == nullptr || bytesToWrite == 0) {
        return 0;
    }

    size_t bytesWritten = 0;
    i2s_write(_i2sPort, (const char*)pcmData, bytesToWrite, &bytesWritten, portMAX_DELAY);
    return bytesWritten;
}

bool AudioPlayer::playWav(const uint8_t* wavData, size_t wavSize) {
    if (!_isInitialized || wavData == nullptr || wavSize < 44) {
        Serial.println(F("[PLAYER] Error: Buffer WAV inválido o nulo"));
        return false;
    }

    // Validación básica de cabecera RIFF/WAVE
    if (memcmp(wavData, "RIFF", 4) != 0 || memcmp(wavData + 8, "WAVE", 4) != 0) {
        Serial.println(F("[PLAYER] Error: Archivo no tiene formato RIFF/WAVE"));
        return false;
    }

    // Buscar el chunk "fmt "
    size_t offset = 12;
    uint32_t sampleRate = 16000;
    uint16_t numChannels = 1;
    uint16_t bitsPerSample = 16;
    size_t dataOffset = 0;
    uint32_t dataBytes = 0;

    while (offset + 8 < wavSize) {
        const char* chunkId = (const char*)(wavData + offset);
        uint32_t chunkSize = *((const uint32_t*)(wavData + offset + 4));

        if (memcmp(chunkId, "fmt ", 4) == 0 && chunkSize >= 16) {
            uint16_t audioFormat = *((const uint16_t*)(wavData + offset + 8));
            numChannels = *((const uint16_t*)(wavData + offset + 10));
            sampleRate = *((const uint32_t*)(wavData + offset + 12));
            bitsPerSample = *((const uint16_t*)(wavData + offset + 22));

            if (audioFormat != 1) { // 1 = Linear PCM
                Serial.printf("[PLAYER] Formato no soportado (audioFormat=%u, se requiere PCM)\n", audioFormat);
                return false;
            }
        } else if (memcmp(chunkId, "data", 4) == 0) {
            dataOffset = offset + 8;
            dataBytes = chunkSize;
            break;
        }

        offset += 8 + chunkSize;
    }

    if (dataOffset == 0 || (dataOffset + dataBytes) > wavSize) {
        Serial.println(F("[PLAYER] No se encontró subchunk 'data' válido en el archivo WAV"));
        return false;
    }

    Serial.printf("[PLAYER] Reproduciendo WAV: %u Hz, %u bits, %s, %u bytes de audio\n",
                  sampleRate, bitsPerSample, (numChannels == 1 ? "Mono" : "Estéreo"), dataBytes);

    setSampleRate(sampleRate);

    const int16_t* pcmSamples = (const int16_t*)(wavData + dataOffset);
    size_t totalSamples = dataBytes / sizeof(int16_t);

    const size_t framesPerBatch = 256;
    int16_t outputStereoBuffer[framesPerBatch * 2];

    if (numChannels == 1) {
        // Expansión de Mono a Estéreo para alimentar ambos canales del MAX98357A
        size_t sampleIdx = 0;
        while (sampleIdx < totalSamples) {
            size_t batchCount = (totalSamples - sampleIdx < framesPerBatch) ? (totalSamples - sampleIdx) : framesPerBatch;
            for (size_t i = 0; i < batchCount; i++) {
                int16_t sample = (int16_t)((float)pcmSamples[sampleIdx + i] * _masterVolume);
                outputStereoBuffer[i * 2] = sample;
                outputStereoBuffer[i * 2 + 1] = sample;
            }

            size_t bytesWritten = 0;
            i2s_write(_i2sPort, (const char*)outputStereoBuffer, batchCount * sizeof(int16_t) * 2, &bytesWritten, portMAX_DELAY);
            sampleIdx += batchCount;
        }
    } else {
        // Ya es estéreo
        size_t frameIdx = 0;
        size_t totalFrames = totalSamples / 2;
        while (frameIdx < totalFrames) {
            size_t batchFrames = (totalFrames - frameIdx < framesPerBatch) ? (totalFrames - frameIdx) : framesPerBatch;
            for (size_t i = 0; i < batchFrames * 2; i++) {
                outputStereoBuffer[i] = (int16_t)((float)pcmSamples[(frameIdx * 2) + i] * _masterVolume);
            }

            size_t bytesWritten = 0;
            i2s_write(_i2sPort, (const char*)outputStereoBuffer, batchFrames * sizeof(int16_t) * 2, &bytesWritten, portMAX_DELAY);
            frameIdx += batchFrames;
        }
    }

    i2s_zero_dma_buffer(_i2sPort);
    Serial.println(F("[PLAYER] Reproducción de audio completada."));
    return true;
}


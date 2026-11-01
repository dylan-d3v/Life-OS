#include "i2s_audio_driver.h"

I2SAudioDriver::I2SAudioDriver() 
    : _isInitialized(false), _i2sPort(I2S_MIC_PORT) {
}

I2SAudioDriver::~I2SAudioDriver() {
    uninstallMicrophone();
}

bool I2SAudioDriver::initMicrophone() {
    if (_isInitialized) {
        return true;
    }

    Serial.println(F("[I2S-MIC] Inicializando controlador I2S para INMP441..."));

    i2s_config_t i2s_config = {
        .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
        .sample_rate = AUDIO_SAMPLE_RATE,
        .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
        .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
        .communication_format = (i2s_comm_format_t)(I2S_COMM_FORMAT_STAND_I2S),
        .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
        .dma_buf_count = I2S_DMA_BUF_COUNT,
        .dma_buf_len = I2S_DMA_BUF_LEN,
        .use_apll = false,
        .tx_desc_auto_clear = false,
        .fixed_mclk = 0
    };

    i2s_pin_config_t pin_config = {
        .bck_io_num = I2S_MIC_SCK_PIN,
        .ws_io_num = I2S_MIC_WS_PIN,
        .data_out_num = I2S_PIN_NO_CHANGE,
        .data_in_num = I2S_MIC_SD_PIN
    };

    esp_err_t err = i2s_driver_install(_i2sPort, &i2s_config, 0, NULL);
    if (err != ESP_OK) {
        Serial.printf("[I2S-MIC] Error instalando driver I2S: 0x%x\n", err);
        return false;
    }

    err = i2s_set_pin(_i2sPort, &pin_config);
    if (err != ESP_OK) {
        Serial.printf("[I2S-MIC] Error configurando pines I2S: 0x%x\n", err);
        i2s_driver_uninstall(_i2sPort);
        return false;
    }

    // Limpia buffers DMA iniciales
    i2s_zero_dma_buffer(_i2sPort);

    _isInitialized = true;
    Serial.printf("[I2S-MIC] Micrófono listo a %d Hz, 16-bit Mono (SCK=%d, WS=%d, SD=%d)\n",
                  AUDIO_SAMPLE_RATE, I2S_MIC_SCK_PIN, I2S_MIC_WS_PIN, I2S_MIC_SD_PIN);
    return true;
}

void I2SAudioDriver::uninstallMicrophone() {
    if (_isInitialized) {
        i2s_driver_uninstall(_i2sPort);
        _isInitialized = false;
        Serial.println(F("[I2S-MIC] Driver desinstalado y recursos DMA liberados."));
    }
}

bool I2SAudioDriver::readSamples(int16_t* buffer, size_t bytesToRead, size_t* bytesRead, TickType_t timeoutTicks) {
    if (!_isInitialized || buffer == nullptr || bytesRead == nullptr) {
        return false;
    }

    esp_err_t err = i2s_read(_i2sPort, (void*)buffer, bytesToRead, bytesRead, timeoutTicks);
    return (err == ESP_OK && *bytesRead > 0);
}

void I2SAudioDriver::clearDmaBuffer() {
    if (_isInitialized) {
        i2s_zero_dma_buffer(_i2sPort);
    }
}

void I2SAudioDriver::applyDigitalGain(int16_t* buffer, size_t sampleCount, float gainFactor) {
    if (buffer == nullptr || gainFactor == 1.0f) {
        return;
    }

    for (size_t i = 0; i < sampleCount; i++) {
        int32_t val = (int32_t)((float)buffer[i] * gainFactor);
        // Saturación a rango de 16 bits firmado [-32768, 32767]
        if (val > 32767) {
            val = 32767;
        } else if (val < -32768) {
            val = -32768;
        }
        buffer[i] = (int16_t)val;
    }
}


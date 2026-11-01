#pragma once

#include <Arduino.h>
#include <driver/i2s.h>
#include "config.h"

/**
 * =============================================================================
 * I2S Audio Driver - Controlador de Entrada (Micrófono INMP441)
 * =============================================================================
 * Configura el puerto I2S0 con buffers DMA en anillo para captura
 * continua de audio digital en formato PCM (16 kHz, 16-bit mono).
 */
class I2SAudioDriver {
public:
    I2SAudioDriver();
    ~I2SAudioDriver();

    /**
     * Inicializa el periférico I2S para captura con el micrófono.
     * @return true si la inicialización fue exitosa.
     */
    bool initMicrophone();

    /**
     * Desinstala el driver I2S para liberar buffers DMA o ahorrar energía.
     */
    void uninstallMicrophone();

    /**
     * Lee un bloque de muestras de audio desde los buffers DMA del I2S.
     * @param buffer Puntero donde se almacenarán las muestras de 16-bit.
     * @param bytesToRead Cantidad de bytes a solicitar del driver I2S.
     * @param bytesRead Puntero donde se almacenará la cantidad real de bytes leídos.
     * @param timeoutTicks Tiempo máximo de espera en ticks de FreeRTOS.
     * @return true si se leyeron datos válidos.
     */
    bool readSamples(int16_t* buffer, size_t bytesToRead, size_t* bytesRead, TickType_t timeoutTicks = portMAX_DELAY);

    /**
     * Limpia los buffers DMA de entrada para descartar ruidos previos al inicio de la grabación.
     */
    void clearDmaBuffer();

    /**
     * Aplica ganancia digital de software con protección contra distorsión (clipping).
     * @param buffer Muestras PCM a amplificar in-place.
     * @param sampleCount Número de muestras en el buffer.
     * @param gainFactor Factor multiplicador (e.g. 2.0f a 4.0f para INMP441).
     */
    static void applyDigitalGain(int16_t* buffer, size_t sampleCount, float gainFactor);

    bool isInitialized() const { return _isInitialized; }

private:
    bool _isInitialized;
    i2s_port_t _i2sPort;
};


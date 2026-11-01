#pragma once

#include <Arduino.h>
#include <driver/i2s.h>
#include "config.h"

enum class SystemTone {
    STARTUP,
    START_LISTENING,
    STOP_LISTENING,
    PROCESSING,
    SUCCESS,
    ERROR_TONE,
    BATTERY_LOW
};

/**
 * =============================================================================
 * Audio Player - Reproductor I2S y Sintetizador de Tonos (MAX98357A)
 * =============================================================================
 * Controla la salida de audio por el puerto I2S1 hacia el amplificador MAX98357A.
 * Proporciona:
 *   1. Generación matemática de tonos y arpegios acústicos de estado en tiempo real.
 *   2. Reproducción de buffers de audio WAV (PCM) en memoria.
 *   3. Reproducción en streaming por bloques (para respuestas de voz TTS por red).
 *   4. Control de volumen digital de 0% a 100%.
 */
class AudioPlayer {
public:
    AudioPlayer();
    ~AudioPlayer();

    /**
     * Inicializa el periférico I2S para salida de audio hacia el MAX98357A.
     * @return true si la inicialización fue exitosa.
     */
    bool begin();

    /**
     * Desinstala el driver I2S de salida.
     */
    void stop();

    /**
     * Reproduce un tono acústico sintetizado en tiempo real.
     */
    void playTone(SystemTone tone);

    /**
     * Genera y reproduce una frecuencia senoidal pura.
     * @param frequencyHz Frecuencia en Hercios (ej: 440 Hz, 880 Hz).
     * @param durationMs Duración del tono en milisegundos.
     * @param volume Factor de amplitud local [0.0f a 1.0f].
     */
    void playSineWave(float frequencyHz, uint32_t durationMs, float volume = 0.5f);

    /**
     * Reproduce un archivo de audio WAV en memoria parseando su cabecera.
     * Reconfigura dinámicamente el reloj de muestreo si la cabecera lo requiere.
     * @param wavData Puntero al inicio del archivo WAV (incluyendo cabecera).
     * @param wavSize Tamaño total en bytes del buffer.
     * @return true si el WAV fue reproducido correctamente.
     */
    bool playWav(const uint8_t* wavData, size_t wavSize);

    /**
     * Reproduce un bloque de audio PCM crudo directamente al DMA.
     * @param pcmData Muestras PCM (16 bits).
     * @param bytesToWrite Cantidad de bytes a escribir.
     * @return Bytes reales transferidos al driver I2S.
     */
    size_t playChunk(const uint8_t* pcmData, size_t bytesToWrite);

    /**
     * Ajusta la frecuencia de muestreo del reloj I2S.
     */
    bool setSampleRate(uint32_t sampleRate);

    /**
     * Configura el nivel de volumen general [0.0f a 1.0f].
     */
    void setVolume(float volume);

    float getVolume() const { return _masterVolume; }
    bool isInitialized() const { return _isInitialized; }

private:
    bool _isInitialized;
    i2s_port_t _i2sPort;
    uint32_t _currentSampleRate;
    float _masterVolume;

    void applyVolumeToSamples(int16_t* dest, const int16_t* src, size_t sampleCount, float vol);
};


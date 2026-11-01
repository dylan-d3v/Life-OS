#pragma once

#include <Arduino.h>
#include "config.h"
#include "i2s_audio_driver.h"

#pragma pack(push, 1)
struct WavHeader {
    char riffTag[4];         // "RIFF"
    uint32_t riffLength;     // Tamaño total del archivo - 8 bytes
    char waveTag[4];         // "WAVE"
    char fmtTag[4];          // "fmt "
    uint32_t fmtLength;      // 16 para PCM
    uint16_t audioFormat;    // 1 = Linear PCM sin compresión
    uint16_t numChannels;    // 1 = Mono
    uint32_t sampleRate;     // 16000 Hz
    uint32_t byteRate;       // sampleRate * numChannels * (bitsPerSample / 8)
    uint16_t blockAlign;     // numChannels * (bitsPerSample / 8)
    uint16_t bitsPerSample;  // 16 bits
    char dataTag[4];         // "data"
    uint32_t dataLength;     // Tamaño en bytes de las muestras de audio
};
#pragma pack(pop)

/**
 * =============================================================================
 * Audio Recorder - Gestor de Grabación de Audio y Generador WAV
 * =============================================================================
 * Almacena en memoria (RAM interna o PSRAM) el audio digital capturado
 * y le añade una cabecera WAV estándar de 44 bytes lista para ser enviada
 * al servicio de transcripción (Groq Whisper / Google STT).
 */
class AudioRecorder {
public:
    AudioRecorder();
    ~AudioRecorder();

    /**
     * Inicializa el grabador asignando buffers de memoria según la disponibilidad de RAM/PSRAM.
     */
    bool begin(I2SAudioDriver* driver, float digitalGain = 2.5f);

    /**
     * Inicia una nueva sesión de grabación, limpiando buffers previos.
     */
    bool startRecording();

    /**
     * Captura un bloque de audio desde el I2S y lo agrega al buffer WAV.
     * Debe llamarse periódicamente en el bucle principal mientras se mantenga presionado el botón.
     * @return true si pudo grabar el bloque, false si se alcanzó el límite de memoria/tiempo.
     */
    bool recordStep();

    /**
     * Detiene la grabación y finaliza la cabecera WAV con el tamaño exacto grabado.
     */
    void stopRecording();

    /**
     * Libera el buffer grabado para recuperar memoria.
     */
    void clear();

    bool isRecording() const { return _isRecording; }
    const uint8_t* getWavBuffer() const { return _wavBuffer; }
    size_t getWavSize() const { return _currentWavSize; }
    size_t getRawAudioBytes() const { return _rawAudioBytes; }
    uint32_t getDurationMs() const;

private:
    I2SAudioDriver* _driver;
    float _digitalGain;
    bool _isRecording;

    uint8_t* _wavBuffer;
    size_t _maxBufferSize;
    size_t _currentWavSize;
    size_t _rawAudioBytes;
    unsigned long _recordStartTime;

    static void populateWavHeader(WavHeader& header, uint32_t sampleRate, uint16_t bitsPerSample, uint16_t channels, uint32_t dataBytes);
};


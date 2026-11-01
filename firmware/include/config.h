#pragma once

#include <Arduino.h>

/**
 * =============================================================================
 * Life-OS Pocket Assistant - Configuración General de Hardware y Pines
 * =============================================================================
 * Soporta compilación automática para:
 *   - ESP32 Clásico (WROOM-32 / DevKit v1)
 *   - ESP32-S3 (ESP32-S3-DevKitC-1)
 */

// =============================================================================
// 1. ASIGNACIÓN DE PINES (PINOUT)
// =============================================================================

#if defined(BOARD_ESP32_S3)
    // -------------------------------------------------------------------------
    // Configuración para ESP32-S3
    // -------------------------------------------------------------------------
    // Micrófono I2S (INMP441 / ICS-43434)
    #define I2S_MIC_SCK_PIN     12  // Bit Clock (SCK / BCLK)
    #define I2S_MIC_WS_PIN      11  // Word Select / LRCK
    #define I2S_MIC_SD_PIN      10  // Serial Data (SD / DIN en micro)
    
    // Amplificador I2S (MAX98357A)
    #define I2S_SPK_BCLK_PIN    7   // Bit Clock
    #define I2S_SPK_LRC_PIN     6   // Left/Right Clock (WS)
    #define I2S_SPK_DIN_PIN     5   // Data Input (DIN en amp)

    // Controles y Señalización
    #define PIN_BUTTON_PTT      4   // Botón Push-to-Talk (RTC Wakeup capaz)
    #define PIN_LED_STATUS      48  // LED RGB direccionable o LED estado
    #define PIN_BATTERY_ADC     1   // Lectura analógica de batería (ADC1_CH0)

#else
    // -------------------------------------------------------------------------
    // Configuración por defecto: ESP32 Clásico (WROOM-32 / DevKit v1)
    // -------------------------------------------------------------------------
    // Micrófono I2S (INMP441)
    #define I2S_MIC_SCK_PIN     14  // SCK / BCLK
    #define I2S_MIC_WS_PIN      15  // WS / LRCK
    #define I2S_MIC_SD_PIN      32  // SD (Data Out del micro)

    // Amplificador I2S (MAX98357A)
    #define I2S_SPK_BCLK_PIN    26  // BCLK
    #define I2S_SPK_LRC_PIN     25  // LRC (WS)
    #define I2S_SPK_DIN_PIN     22  // DIN

    // Controles y Señalización
    #define PIN_BUTTON_PTT      33  // Botón Push-to-Talk (RTC GPIO compatible con ext0)
    #define PIN_LED_STATUS      2   // LED azul incorporado en placa
    #define PIN_BATTERY_ADC     34  // Entrada ADC para batería (solo lectura / sin pullup)

#endif

// =============================================================================
// 2. CONFIGURACIÓN DE AUDIO I2S
// =============================================================================
#define AUDIO_SAMPLE_RATE       16000   // 16 kHz (Estándar para STT / Whisper)
#define AUDIO_BITS_PER_SAMPLE   16      // 16 bits por muestra
#define AUDIO_CHANNELS          1       // 1 canal (Mono)

// Puertos I2S del ESP32 (El ESP32 dispone de I2S0 e I2S1 independientes)
#define I2S_MIC_PORT            I2S_NUM_0   // Puerto dedicado a captura de micrófono
#define I2S_SPK_PORT            I2S_NUM_1   // Puerto dedicado a reproducción de altavoz

// Parámetros del Buffer DMA
#define I2S_DMA_BUF_COUNT       8       // Cantidad de buffers DMA en anillo
#define I2S_DMA_BUF_LEN         512     // Longitud de cada buffer DMA (muestras)

// Límites de grabación
#define AUDIO_MAX_RECORD_SECS   15      // Límite de seguridad: 15 segundos máx por comando
#define AUDIO_BUFFER_SIZE_BYTES (AUDIO_SAMPLE_RATE * (AUDIO_BITS_PER_SAMPLE / 8) * AUDIO_MAX_RECORD_SECS)

// =============================================================================
// 3. PARÁMETROS DEL SISTEMA Y GESTIÓN DE ENERGÍA
// =============================================================================
#define BUTTON_DEBOUNCE_MS      50      // Tiempo antirrebote para el botón PTT
#define INACTIVITY_SLEEP_MS     30000   // 30 segundos sin actividad -> Deep Sleep
#define BATTERY_VOLTAGE_MIN     3.3f    // Umbral de batería crítica (Voltios)
#define BATTERY_VOLTAGE_MAX     4.2f    // Voltaje de carga completa (LiPo 3.7V nominal)
#define BATTERY_R1_OHMS         100000  // Divisor de tensión: R1 = 100kΩ
#define BATTERY_R2_OHMS         100000  // Divisor de tensión: R2 = 100kΩ (Factor = 2.0)

// =============================================================================
// 4. PARÁMETROS DE RED Y SERVICIOS LIFE-OS
// =============================================================================
// Credenciales Wi-Fi por defecto (pueden sobreescribirse mediante NVS)
#ifndef WIFI_DEFAULT_SSID
#define WIFI_DEFAULT_SSID       "MI_RED_WIFI"
#endif

#ifndef WIFI_DEFAULT_PASS
#define WIFI_DEFAULT_PASS       "MI_CONTRASENA"
#endif

// Gateway / Companion Endpoint de Life-OS
// En desarrollo puede apuntar a la IP local de la PC ejecutando companion_gateway.py
// En producción apunta a la Edge Function HTTPS de Supabase
#ifndef LIFE_OS_GATEWAY_URL
#define LIFE_OS_GATEWAY_URL     "http://192.168.1.100:8080/api/assistant"
#endif

#define LIFE_OS_DEVICE_ID       "pocket-assistant-01"
#define HTTP_REQUEST_TIMEOUT_MS 15000   // 15 segundos timeout de red


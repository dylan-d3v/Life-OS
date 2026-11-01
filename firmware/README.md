# Life-OS Pocket Assistant - Firmware (ESP32)

Este directorio contiene el firmware del **asistente de bolsillo autónomo** para el ecosistema **Life-OS**, impulsado por el motor de inteligencia **Kev**.

---

## 1. Lista de Materiales (BOM)

| Componente | Modelo Recomendado | Notas |
| :--- | :--- | :--- |
| **Microcontrolador** | ESP32 NodeMCU-32 / ESP32-S3 DevKit | Dual Core, Wi-Fi 2.4 GHz, soporte DMA para I2S. |
| **Micrófono Digital** | INMP441 (I2S) | Omnidireccional digital, SNR 61 dBA. Funciona a **3.3V estrictos**. |
| **Amplificador DAC** | MAX98357A (I2S) | Decodificador I2S a clase D de 3.2W. Alimentable a 3.3V o 5V. |
| **Altavoz** | Mini parlante 8Ω (1W a 2W) | Diámetro 28mm a 40mm para carcasa de bolsillo. |
| **Pulsador (PTT)** | Botón táctil normalmente abierto | Conectado entre el pin RTC GPIO y GND. |
| **LED Indicador** | LED azul integrado o RGB WS2812B | Feedback visual de estado de grabación/red/batería. |
| **Batería** | Batería LiPo 3.7V (500 a 1200 mAh) | Provee autonomía para cientos de comandos de voz. |
| **Carga LiPo** | Módulo TP4056 con protección | Conector USB-C para recarga segura. |
| **Divisor Resistivo** | 2x Resistencias de 100kΩ | Para telemetría del voltaje de la batería vía ADC. |

---

## 2. Esquemático de Conexiones (Pinout)

### 2.1 Conexión del Micrófono I2S (INMP441)
> ⚠️ **Importante:** El pin `VDD` del INMP441 debe conectarse a **3.3V**. Conectarlo a 5V destruirá el chip.

| Pin INMP441 | Función | ESP32 Clásico (WROOM-32) | ESP32-S3 |
| :--- | :--- | :--- | :--- |
| **VDD** | Alimentación 3.3V | 3V3 | 3V3 |
| **GND** | Tierra común | GND | GND |
| **SD** | Serial Data (Salida) | **GPIO 32** | **GPIO 10** |
| **WS** | Word Select / LRCK | **GPIO 15** | **GPIO 11** |
| **SCK** | Bit Clock (BCLK) | **GPIO 14** | **GPIO 12** |
| **L/R** | Canal Izquierdo/Derecho | **GND** (Canal izquierdo) | **GND** (Canal izquierdo) |

---

### 2.2 Conexión del Amplificador I2S (MAX98357A)

| Pin MAX98357A | Función | ESP32 Clásico (WROOM-32) | ESP32-S3 |
| :--- | :--- | :--- | :--- |
| **VIN** | Alimentación (3.3V o 5V) | 5V / VIN (o 3V3) | 5V / VIN (o 3V3) |
| **GND** | Tierra común | GND | GND |
| **DIN** | Serial Data Input | **GPIO 22** | **GPIO 5** |
| **BCLK** | Bit Clock | **GPIO 26** | **GPIO 7** |
| **LRC** | Left/Right Clock (WS) | **GPIO 25** | **GPIO 6** |
| **GAIN** | Control de Ganancia | **GND** (Ganancia de 12dB) | **GND** (Ganancia de 12dB) |
| **SD** | Shutdown / Modo estéreo | Sin conectar (flotante) | Sin conectar (flotante) |
| **+ / -** | Salida a altavoz | Bornes del altavoz 8Ω | Bornes del altavoz 8Ω |

---

### 2.3 Botón Push-to-Talk (PTT) y Señales de Control

| Componente | Pin Sensor / Control | Pin ESP32 Clásico | Pin ESP32-S3 | Notas |
| :--- | :--- | :--- | :--- | :--- |
| **Botón PTT** | Terminal 1 | **GPIO 33** | **GPIO 4** | Configurado como `INPUT_PULLUP`. Pin RTC para despertar de *Deep Sleep*. |
| | Terminal 2 | **GND** | **GND** | Al pulsar cierra a tierra (activo en LOW). |
| **LED Estado** | Ánodo (+) / Señal | **GPIO 2** (Onboard) | **GPIO 48** | Indicador de grabación, procesamiento y error. |
| **Batería (ADC)** | Punto medio divisor | **GPIO 34** | **GPIO 1** | Lectura analógica de LiPo (0 a 4.2V divididos entre 2). |

---

### 2.4 Circuito Divisor de Tensión para Batería
```
  Batería LiPo (+) [3.0V - 4.2V]
         │
       [100kΩ R1]
         │
         ├───> GPIO 34 (ESP32) / GPIO 1 (ESP32-S3) [Lectura ADC: 1.5V - 2.1V]
         │
       [100kΩ R2]
         │
        GND
```

---

## 3. Compilación y Carga con PlatformIO

### Opción A: Usando PlatformIO en VS Code
1. Abre la carpeta `firmware/` en VS Code con la extensión **PlatformIO IDE** instalada.
2. Selecciona el entorno objetivo en la barra inferior:
   - `env:esp32dev` para ESP32 estándar.
   - `env:esp32s3` para ESP32-S3.
3. Haz clic en **Build** (ícono de verificación) y luego en **Upload** (ícono de flecha).
4. Abre el **Serial Monitor** a 115200 baudios.

### Opción B: Usando la Terminal de PlatformIO CLI
```bash
# Para compilar entorno ESP32 clásico
pio run -e esp32dev

# Para subir firmware y abrir monitor serial
pio run -e esp32dev -t upload -t monitor
```


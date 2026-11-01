# Guía de Flasheo, Depuración y Solución de Problemas (Troubleshooting)

Este documento contiene la guía paso a paso para compilar, flashear y diagnosticar el hardware del **asistente de bolsillo autónomo (ESP32)** de **Life-OS**.

---

## 1. Guía Rápida de Puesta en Marcha (Paso a Paso)

### Paso 1: Preparar el Servidor Gateway Local
En tu computadora de desarrollo, inicia el servidor companion que conecta el ESP32 con Kev y el sintetizador de voz:
```bash
python firmware/tools/companion_gateway.py
```
El servidor mostrará en pantalla la **IP local de tu PC** (por ejemplo: `192.168.1.105`).

---

### Paso 2: Configurar Parámetros en el Firmware
Abre el archivo [include/config.h](file:///c:/Users/dylan/Desktop/Repositories/Life-OS/firmware/include/config.h) y edita tus credenciales:
```cpp
#define WIFI_DEFAULT_SSID       "Tu_Nombre_De_WiFi"
#define WIFI_DEFAULT_PASS       "Tu_Contraseña_De_WiFi"
#define LIFE_OS_GATEWAY_URL     "http://192.168.1.105:8080/api/assistant"
```
*(También puedes persistir estas credenciales permanentemente en la memoria Flash NVS sin recompilar).*

---

### Paso 3: Compilar y Flashear el ESP32
Conecta el ESP32 a tu PC mediante cable de datos USB-C / Micro-USB.

#### Opción A: Con PlatformIO CLI
```bash
# Para ESP32 clásico (WROOM-32 / DevKit v1)
pio run -e esp32dev -t upload -t monitor

# Para ESP32-S3
pio run -e esp32s3 -t upload -t monitor
```

#### Opción B: Con la Extensión de PlatformIO en VS Code
1. Abre la carpeta `firmware/`.
2. En la barra inferior, selecciona el entorno (`esp32dev` o `esp32s3`).
3. Haz clic en **Upload** y luego en el ícono de enchufe (**Serial Monitor** a 115200 baudios).

---

## 2. Diagnóstico de Problemas de Hardware

### 🔴 Problema 1: No se escucha ningún sonido por el altavoz (MAX98357A)
* **Causa 1 (Pines I2S cruzados):** Verifica que `BCLK` vaya a GPIO 26, `LRC/WS` a GPIO 25 y `DIN` a GPIO 22.
* **Causa 2 (Pin de ganancia GAIN):** Si el pin GAIN está al aire, la ganancia es de 9dB. Conéctalo a **GND** para una ganancia estándar de **12dB**.
* **Causa 3 (Alimentación insuficiente):** El amplificador clase D puede requerir picos de hasta 1A a máximo volumen. Aliméntalo desde el pin **VIN / 5V** del ESP32, no desde el pin de 3.3V.

---

### 🔴 Problema 2: El ESP32 se reinicia al sonar el altavoz (*Brownout detector was triggered*)
* **Causa:** El pico repentino de corriente del altavoz causa una caída de voltaje (*voltage dip*) en la línea de 5V/3.3V que activa la protección interna del ESP32.
* **Solución:**
  1. Conecta un condensador electrolítico de **100 µF a 470 µF (10V o 16V)** entre el pin `VIN` y `GND` del amplificador MAX98357A.
  2. Utiliza un cable USB de mayor calidad o un puerto USB 3.0 / cargador externo.
  3. Reduce el volumen en el firmware: `audioPlayer.setVolume(0.70f);`.

---

### 🔴 Problema 3: El micrófono INMP441 solo captura silencio o ruido blanco
* **Causa 1 (Pin L/R desconectado):** El pin `L/R` determina el canal I2S. **DEBE estar conectado obligatoriamente a GND** para que transmita en el canal izquierdo (que es el canal configurado en el driver).
* **Causa 2 (Voltaje incorrecto):** El INMP441 solo tolera **3.3V**. Conectarlo a 5V puede dañarlo permanentemente.
* **Causa 3 (Buffer DMA desalineado):** Si el audio suena acelerado o como ardilla, verifica que la frecuencia en `config.h` coincida exactamente con los 16000 Hz del driver.

---

### 🔴 Problema 4: El botón PTT no despierta al microcontrolador de Deep Sleep
* **Causa:** En el ESP32, la función `esp_sleep_enable_ext0_wakeup` requiere que el pin pertenezca al dominio **RTC GPIO**.
  * Pines RTC válidos en ESP32 clásico: GPIO 0, 2, 4, 12, 13, 14, 15, 25, 26, 27, **32**, **33**, **34**, **35**, **36**, **39**.
  * En nuestro firmware, el botón PTT usa **GPIO 33** (o GPIO 4 en ESP32-S3), ambos con soporte RTC garantizado.
* **Solución:** Asegúrate de que el botón cierre el circuito hacia **GND** al presionarse (lógica activa en LOW).

---

### 🔴 Problema 5: Error de conexión HTTP hacia el Companion Gateway
* **Causa:** El firewall de Windows o la red Wi-Fi bloquea el puerto 8080.
* **Solución:**
  1. Verifica que la PC y el ESP32 estén conectados a la **misma red Wi-Fi (2.4 GHz)**.
  2. Agrega una regla de entrada en el Firewall de Windows para permitir tráfico en el puerto `8080`.
  3. Comprueba el estado del servidor desde el navegador de tu teléfono o PC ingresando a: `http://TU_IP_LOCAL:8080/health`.


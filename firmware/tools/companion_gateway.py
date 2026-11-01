#!/usr/bin/env python3
"""
=============================================================================
Life-OS Pocket Assistant - Companion Gateway & Test Server
=============================================================================
Servidor local ligero en Python (sin dependencias externas obligatorias)
que actúa como pasarela para el ESP32:
  1. POST /stt               : Recibe audio WAV del ESP32 y transcribe con Whisper.
  2. POST /api/assistant     : Procesa la intención con Kev y ejecuta acciones.
  3. GET  /tts               : Genera voz sintetizada WAV de confirmación para el altavoz.
  4. GET  /health            : Verificación de conectividad y estado del gateway.
"""

import http.server
import socketserver
import urllib.parse
import urllib.request
import json
import os
import sys
import wave
import math
import struct
import socket
import subprocess
import tempfile
import time

PORT = 8080

def get_local_ip():
    """Detecta la dirección IP de la interfaz local para mostrarla al desarrollador."""
    try:
        s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        s.connect(("8.8.8.8", 80))
        ip = s.getsockname()[0]
        s.close()
        return ip
    except Exception:
        return "127.0.0.1"

def load_env_file():
    """Carga claves desde el archivo .env de la raíz del proyecto si existe."""
    env_path = os.path.join(os.path.dirname(__file__), "..", "..", ".env")
    env_vars = {}
    if os.path.exists(env_path):
        try:
            with open(env_path, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        env_vars[k.strip()] = v.strip().strip('"').strip("'")
        except Exception as e:
            print(f"[ENV] Error leyendo .env: {e}")
    return env_vars

ENV_CONFIG = load_env_file()
GROQ_KEY = os.environ.get("GROQ_API_KEY", ENV_CONFIG.get("GROQ_API_KEY", ""))
GEMINI_KEY = os.environ.get("GEMINI_API_KEY", ENV_CONFIG.get("GEMINI_API_KEY", ""))

def generate_fallback_wav(frequency=440.0, duration_secs=0.8, sample_rate=16000):
    """Genera un buffer WAV sintético en memoria como fallback de audio."""
    num_samples = int(sample_rate * duration_secs)
    raw_pcm = bytearray()
    for i in range(num_samples):
        t = float(i) / sample_rate
        # Envolvente suave para evitar clicks
        envelope = math.sin(math.pi * (i / num_samples))
        val = int(math.sin(2.0 * math.pi * frequency * t) * 28000.0 * envelope)
        raw_pcm += struct.pack("<h", max(-32768, min(32767, val)))

    # Cabecera WAV (44 bytes)
    header = bytearray(b"RIFF")
    header += struct.pack("<I", 36 + len(raw_pcm))
    header += b"WAVEfmt "
    header += struct.pack("<I", 16)      # Subchunk1Size
    header += struct.pack("<H", 1)       # AudioFormat (PCM)
    header += struct.pack("<H", 1)       # NumChannels (Mono)
    header += struct.pack("<I", sample_rate)
    header += struct.pack("<I", sample_rate * 2) # ByteRate
    header += struct.pack("<H", 2)       # BlockAlign
    header += struct.pack("<H", 16)      # BitsPerSample
    header += b"data"
    header += struct.pack("<I", len(raw_pcm))

    return bytes(header + raw_pcm)

def synthesize_windows_speech(text):
    """Genera audio WAV usando el sintetizador de voz nativo de Windows (System.Speech)."""
    if sys.platform != "win32":
        return None

    try:
        temp_wav = os.path.join(tempfile.gettempdir(), f"lifeos_tts_{int(time.time()*1000)}.wav")
        # Script PowerShell que sintetiza el texto en un archivo WAV PCM
        safe_text = text.replace("'", " ").replace('"', " ")
        ps_cmd = (
            f"Add-Type -AssemblyName System.Speech; "
            f"$s = New-Object System.Speech.Synthesis.SpeechSynthesizer; "
            f"$s.SetOutputToWaveFile('{temp_wav}'); "
            f"$s.Speak('{safe_text}'); "
            f"$s.Dispose();"
        )
        res = subprocess.run(["powershell", "-NoProfile", "-Command", ps_cmd], capture_output=True, timeout=6)
        if res.returncode == 0 and os.path.exists(temp_wav):
            with open(temp_wav, "rb") as f:
                wav_bytes = f.read()
            try:
                os.remove(temp_wav)
            except Exception:
                pass
            return wav_bytes
    except Exception as e:
        print(f"[TTS] Error con PowerShell SpeechSynthesizer: {e}")
    return None

class LifeOSCompanionHandler(http.server.BaseHTTPRequestHandler):

    def _send_json(self, status_code, data):
        payload = json.dumps(data, ensure_ascii=False).encode("utf-8")
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def _send_wav(self, wav_bytes):
        self.send_response(200)
        self.send_header("Content-Type", "audio/wav")
        self.send_header("Content-Length", str(len(wav_bytes)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(wav_bytes)

    def do_GET(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        params = urllib.parse.parse_qs(parsed.query)

        # -------------------------------------------------------------
        # Health Check
        # -------------------------------------------------------------
        if path == "/health" or path == "/api/assistant/health":
            self._send_json(200, {
                "status": "online",
                "service": "Life-OS Companion Gateway",
                "version": "1.0.0",
                "local_ip": get_local_ip(),
                "has_groq_key": bool(GROQ_KEY),
                "has_gemini_key": bool(GEMINI_KEY),
                "timestamp": time.time()
            })
            return

        # -------------------------------------------------------------
        # Text-to-Speech (TTS) Endpoint
        # -------------------------------------------------------------
        if path == "/tts" or path == "/api/assistant/tts":
            text = params.get("text", ["Acción ejecutada en Life OS"])[0]
            print(f"[GATEWAY - TTS] Solicitud de síntesis: \"{text}\"")

            wav_data = synthesize_windows_speech(text)
            if not wav_data:
                # Si falla o no es Windows, generar tono acústico de confirmación melódico
                wav_data = generate_fallback_wav(frequency=587.33, duration_secs=0.7)

            self._send_wav(wav_data)
            return

        self._send_json(404, {"error": "Endpoint no encontrado"})

    def do_POST(self):
        parsed = urllib.parse.urlparse(self.path)
        path = parsed.path
        content_length = int(self.headers.get("Content-Length", 0))
        body = self.rfile.read(content_length)

        # -------------------------------------------------------------
        # STT (Speech-to-Text) Endpoint
        # -------------------------------------------------------------
        if path == "/stt" or path == "/api/assistant/stt":
            print(f"[GATEWAY - STT] Recibido paquete de audio WAV: {len(body)} bytes")

            # Si hay clave de Groq disponible, enviar a Groq Whisper
            if GROQ_KEY:
                try:
                    boundary = "----LifeOsFormBoundary" + str(int(time.time()))
                    form_data = bytearray()
                    
                    # Campo model
                    form_data += f"--{boundary}\r\nContent-Disposition: form-data; name=\"model\"\r\n\r\nwhisper-large-v3-turbo\r\n".encode()
                    # Campo language
                    form_data += f"--{boundary}\r\nContent-Disposition: form-data; name=\"language\"\r\n\r\nes\r\n".encode()
                    # Archivo WAV
                    form_data += f"--{boundary}\r\nContent-Disposition: form-data; name=\"file\"; filename=\"voice.wav\"\r\nContent-Type: audio/wav\r\n\r\n".encode()
                    form_data += body
                    form_data += f"\r\n--{boundary}--\r\n".encode()

                    req = urllib.request.Request(
                        "https://api.groq.com/openai/v1/audio/transcriptions",
                        data=form_data,
                        headers={
                            "Authorization": f"Bearer {GROQ_KEY}",
                            "Content-Type": f"multipart/form-data; boundary={boundary}"
                        }
                    )
                    with urllib.request.urlopen(req, timeout=12) as response:
                        res_json = json.loads(response.read().decode("utf-8"))
                        transcription = res_json.get("text", "").strip()
                        print(f"[GATEWAY - STT] Transcripción Whisper Cloud: \"{transcription}\"")
                        self._send_json(200, {"text": transcription})
                        return
                except Exception as e:
                    print(f"[GATEWAY - STT] Error en Groq Whisper API: {e}. Usando transcripción simulada...")

            # Fallback inteligente simulado si no hay clave de Groq o no hay red
            simulated_text = "Comprar pan mañana a las 5pm" if len(body) > 30000 else "Revisar agenda de hoy"
            print(f"[GATEWAY - STT] Transcripción simulada: \"{simulated_text}\"")
            self._send_json(200, {"text": simulated_text})
            return

        # -------------------------------------------------------------
        # Assistant / Kev Intent Dispatcher Endpoint
        # -------------------------------------------------------------
        if path == "/api/assistant" or path == "/api/assistant/command":
            try:
                data = json.loads(body.decode("utf-8"))
            except Exception:
                data = {}

            user_text = data.get("text", "").strip()
            device_id = data.get("device_id", "unknown")
            print(f"[GATEWAY - KEV] Comando recibido de {device_id}: \"{user_text}\"")

            # Heurística simple de intención para el servidor de desarrollo
            lower = user_text.lower()
            if "tarea" in lower or "comprar" in lower or "hacer" in lower or "llamar" in lower:
                action = "create_task"
                title = user_text.replace("crear tarea", "").replace("tarea", "").strip()
                summary = f"Tarea creada: {title.capitalize() if title else 'Nueva tarea'}"
                tts_msg = f"Tarea registrada: {title if title else 'nueva tarea'}"
            elif "nota" in lower or "recordar" in lower:
                action = "create_note"
                summary = f"Nota guardada: {user_text}"
                tts_msg = "Nota guardada correctamente en Life OS"
            elif "hoy" in lower or "agenda" in lower or "pendiente" in lower or "resumen" in lower:
                action = "query_briefing"
                summary = "Tienes 2 tareas pendientes y 1 evento para hoy"
                tts_msg = "Hoy tienes dos tareas pendientes y un evento en tu calendario"
            elif "gasto" in lower or "pago" in lower or "compre" in lower or "$" in lower:
                action = "log_finance"
                summary = "Gasto registrado en Finanzas"
                tts_msg = "Gasto registrado correctamente en tu balance"
            else:
                action = "create_task"
                summary = f"Tarea creada: {user_text}"
                tts_msg = f"Acción registrada: {user_text}"

            response_data = {
                "success": True,
                "action": action,
                "summary": summary,
                "ttsMessage": tts_msg,
                "error": None
            }
            print(f"[GATEWAY - KEV] Respuesta: {json.dumps(response_data, ensure_ascii=False)}")
            self._send_json(200, response_data)
            return

        self._send_json(404, {"error": "Endpoint no soportado"})

def run_server():
    local_ip = get_local_ip()
    print("=" * 65)
    print("  LIFE-OS POCKET ASSISTANT - COMPANION GATEWAY SERVER")
    print("=" * 65)
    print(f"  • IP Local de la PC      : {local_ip}")
    print(f"  • Puerto de Escucha      : {PORT}")
    print(f"  • URL Base para el ESP32 : http://{local_ip}:{PORT}/api/assistant")
    print(f"  • Whisper STT            : {'Habilitado (Groq Cloud)' if GROQ_KEY else 'Modo Simulado / Fallback'}")
    print(f"  • Síntesis TTS           : {'Windows Native SpeechSynthesizer' if sys.platform == 'win32' else 'Acoustic Tone Synth'}")
    print("=" * 65)
    print(f"[INIT] Servidor escuchando en http://0.0.0.0:{PORT}...")
    print("[INIT] Puedes flashear tu ESP32 apuntando LIFE_OS_GATEWAY_URL a esta IP.")
    print("       Presiona Ctrl + C para detener el servidor.\n")

    socketserver.TCPServer.allow_reuse_address = True
    with socketserver.TCPServer(("0.0.0.0", PORT), LifeOSCompanionHandler) as httpd:
        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n[INFO] Servidor detenido por el usuario.")

if __name__ == "__main__":
    run_server()


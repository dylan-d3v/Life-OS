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
    """Carga claves desde los archivos .env del proyecto (raíz y subdirectorio life_os)."""
    base_dir = os.path.dirname(os.path.abspath(__file__))
    candidates = [
        os.path.join(base_dir, "..", "..", ".env"),
        os.path.join(base_dir, "..", "..", "life_os", ".env"),
    ]
    env_vars = {}
    for env_path in candidates:
        if os.path.exists(env_path):
            try:
                with open(env_path, "r", encoding="utf-8") as f:
                    for line in f:
                        line = line.strip()
                        if line and not line.startswith("#") and "=" in line:
                            k, v = line.split("=", 1)
                            env_vars[k.strip()] = v.strip().strip('"').strip("'")
            except Exception as e:
                print(f"[ENV] Error leyendo {env_path}: {e}")
    return env_vars

ENV_CONFIG = load_env_file()
GROQ_KEY = os.environ.get("GROQ_API_KEY", ENV_CONFIG.get("GROQ_API_KEY", ""))
GEMINI_KEY = os.environ.get("GEMINI_API_KEY", ENV_CONFIG.get("GEMINI_API_KEY", ""))
SUPABASE_URL = os.environ.get("SUPABASE_URL", ENV_CONFIG.get("SUPABASE_URL", ""))
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", ENV_CONFIG.get("SUPABASE_ANON_KEY", ""))

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

def dispatch_kev_action(user_text, device_id="unknown"):
    """
    Despacha la orden de voz del satélite ESP32.
    Determina la intención estructurada (tareas, notas, finanzas, eventos, briefing)
    y genera una confirmación auditiva en español claro.
    """
    if not user_text:
        return {
            "success": False,
            "action": "unknown",
            "summary": "Comando vacío",
            "ttsMessage": "No he podido escuchar tu orden con claridad. Por favor repítela.",
            "error": "Texto vacío"
        }

    lower = user_text.lower().strip()

    # 1. Tareas (create_task)
    if any(k in lower for k in ["tarea", "comprar", "hacer", "llamar", "recordatorio", "pendiente"]):
        clean = user_text
        for prefix in ["crear tarea", "anota tarea", "anotar tarea", "nueva tarea", "recuérdame", "recuerdame", "tarea"]:
            if clean.lower().startswith(prefix):
                clean = clean[len(prefix):].strip()
        clean = clean.lstrip(":,- ").strip()
        title = clean.capitalize() if clean else "Nueva tarea"
        return {
            "success": True,
            "action": "create_task",
            "summary": f"Tarea creada: \"{title}\"",
            "ttsMessage": f"Tarea registrada: {title}.",
            "error": None
        }

    # 2. Notas (create_note)
    if any(k in lower for k in ["nota", "apunte", "recordar", "anota esto", "escribe", "idea"]):
        clean = user_text
        for prefix in ["crear nota", "anotar nota", "nueva nota", "anota esto", "apunta esto", "nota"]:
            if clean.lower().startswith(prefix):
                clean = clean[len(prefix):].strip()
        clean = clean.lstrip(":,- ").strip()
        title = clean.capitalize() if clean else "Nueva nota"
        return {
            "success": True,
            "action": "create_note",
            "summary": f"Nota guardada: \"{title}\"",
            "ttsMessage": f"Nota guardada en tu bóveda de Life OS: {title}.",
            "error": None
        }

    # 3. Finanzas (log_finance)
    if any(k in lower for k in ["gasto", "gasté", "gaste", "pago", "pagué", "pague", "compré", "compre", "costó", "costo", "$", "dólares", "euros", "soles", "pesos"]):
        return {
            "success": True,
            "action": "log_finance",
            "summary": f"Transacción financiera registrada: {user_text}",
            "ttsMessage": "Gasto registrado correctamente en tu balance financiero.",
            "error": None
        }

    # 4. Calendario (create_calendar_event)
    if any(k in lower for k in ["reunión", "reunion", "evento", "cita", "calendario"]):
        clean = user_text
        for prefix in ["programar reunión", "agendar cita", "nuevo evento", "reunión", "reunion"]:
            if clean.lower().startswith(prefix):
                clean = clean[len(prefix):].strip()
        clean = clean.lstrip(":,- ").strip()
        title = clean.capitalize() if clean else "Reunión"
        return {
            "success": True,
            "action": "create_calendar_event",
            "summary": f"Evento programado: \"{title}\"",
            "ttsMessage": f"Evento agendado en tu calendario: {title}.",
            "error": None
        }

    # 5. Briefing / Consulta de resumen diario
    if any(k in lower for k in ["hoy", "agenda", "resumen", "pendientes", "qué tengo", "que tengo", "briefing"]):
        return {
            "success": True,
            "action": "query_briefing",
            "summary": "Consulta de Briefing Diario ejecutada",
            "ttsMessage": "Hola. Tienes tus tareas del día y eventos sincronizados en tu teléfono.",
            "error": None
        }

    # Fallback general a creación de tarea rápida
    return {
        "success": True,
        "action": "create_task",
        "summary": f"Tarea creada: \"{user_text.capitalize()}\"",
        "ttsMessage": f"Acción procesada y registrada: {user_text}.",
        "error": None
    }


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

            response_data = dispatch_kev_action(user_text, device_id)
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


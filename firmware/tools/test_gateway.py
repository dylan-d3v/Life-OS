#!/usr/bin/env python3
"""
Test Suite para Life-OS Companion Gateway & Voice Pipeline
==========================================================
Verifica:
1. Análisis de intenciones y acciones tipadas (tareas, notas, finanzas, eventos, briefing).
2. Generación y síntesis de audio WAV (cabeceras RIFF/WAVE, PCM 16-bit 16kHz).
3. Endpoints HTTP reales en servidor local (/health, /stt, /api/assistant, /tts).
"""

import unittest
import urllib.request
import urllib.parse
import json
import threading
import time
import socketserver
import os
import sys

# Agregar ruta para importar companion_gateway
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import companion_gateway as cg

TEST_PORT = 8089

class TestCompanionGatewayUnit(unittest.TestCase):
    def test_dispatch_create_task(self):
        res = cg.dispatch_kev_action("Anota tarea comprar módulo MAX98357A")
        self.assertTrue(res["success"])
        self.assertEqual(res["action"], "create_task")
        self.assertIn("max98357a", res["summary"].lower())
        self.assertTrue(len(res["ttsMessage"]) > 0)
        self.assertIsNone(res["error"])

    def test_dispatch_create_note(self):
        res = cg.dispatch_kev_action("Crear nota: Revisar pines BCLK y LRCK del ESP32")
        self.assertTrue(res["success"])
        self.assertEqual(res["action"], "create_note")
        self.assertIn("Revisar pines", res["summary"])
        self.assertTrue("Nota guardada" in res["ttsMessage"])

    def test_dispatch_log_finance(self):
        res = cg.dispatch_kev_action("Gasté 24 dólares en componentes de hardware")
        self.assertTrue(res["success"])
        self.assertEqual(res["action"], "log_finance")
        self.assertIn("Gasto registrado", res["ttsMessage"])

    def test_dispatch_calendar_event(self):
        res = cg.dispatch_kev_action("Programar reunión de hardware el viernes a las 3pm")
        self.assertTrue(res["success"])
        self.assertEqual(res["action"], "create_calendar_event")
        self.assertIn("Evento agendado", res["ttsMessage"])

    def test_dispatch_query_briefing(self):
        res = cg.dispatch_kev_action("Kev, qué tengo para hoy en mi agenda")
        self.assertTrue(res["success"])
        self.assertEqual(res["action"], "query_briefing")
        self.assertIn("tareas del día", res["ttsMessage"])

    def test_dispatch_empty_command(self):
        res = cg.dispatch_kev_action("")
        self.assertFalse(res["success"])
        self.assertEqual(res["action"], "unknown")
        self.assertIsNotNone(res["error"])

    def test_generate_fallback_wav(self):
        wav = cg.generate_fallback_wav(frequency=440.0, duration_secs=0.5, sample_rate=16000)
        self.assertGreater(len(wav), 44)
        self.assertEqual(wav[:4], b"RIFF")
        self.assertEqual(wav[8:12], b"WAVE")
        self.assertEqual(wav[12:16], b"fmt ")

    def test_synthesize_windows_speech(self):
        if sys.platform == "win32":
            wav = cg.synthesize_windows_speech("Hola desde Life OS")
            self.assertIsNotNone(wav)
            self.assertGreater(len(wav), 44)
            self.assertEqual(wav[:4], b"RIFF")


class TestCompanionGatewayHttp(unittest.TestCase):
    server = None
    server_thread = None

    @classmethod
    def setUpClass(cls):
        socketserver.TCPServer.allow_reuse_address = True
        cls.server = socketserver.TCPServer(("127.0.0.1", TEST_PORT), cg.LifeOSCompanionHandler)
        cls.server_thread = threading.Thread(target=cls.server.serve_forever, daemon=True)
        cls.server_thread.start()
        time.sleep(0.3)

    @classmethod
    def tearDownClass(cls):
        if cls.server:
            cls.server.shutdown()
            cls.server.server_close()

    def test_health_endpoint(self):
        req = urllib.request.Request(f"http://127.0.0.1:{TEST_PORT}/health")
        with urllib.request.urlopen(req, timeout=5) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn(data.get("status"), ["ok", "online"])
            self.assertEqual(data.get("service"), "Life-OS Companion Gateway")

    def test_api_assistant_command(self):
        payload = json.dumps({
            "text": "Anota comprar estaño y pasta para soldar",
            "device_id": "esp32-unit-test"
        }).encode("utf-8")
        req = urllib.request.Request(
            f"http://127.0.0.1:{TEST_PORT}/api/assistant/command",
            data=payload,
            headers={"Content-Type": "application/json"}
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertTrue(data.get("success"))
            self.assertEqual(data.get("action"), "create_task")
            self.assertIn("estaño", data.get("summary", "").lower())

    def test_stt_endpoint(self):
        sample_wav = cg.generate_fallback_wav(duration_secs=0.2)
        req = urllib.request.Request(
            f"http://127.0.0.1:{TEST_PORT}/stt",
            data=sample_wav,
            headers={"Content-Type": "audio/wav"}
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            self.assertEqual(resp.status, 200)
            data = json.loads(resp.read().decode("utf-8"))
            self.assertIn("text", data)
            self.assertGreater(len(data["text"]), 0)

    def test_tts_endpoint(self):
        url = f"http://127.0.0.1:{TEST_PORT}/tts?text=" + urllib.parse.quote("Prueba de audio")
        req = urllib.request.Request(url)
        with urllib.request.urlopen(req, timeout=8) as resp:
            self.assertEqual(resp.status, 200)
            self.assertEqual(resp.headers.get("Content-Type"), "audio/wav")
            audio_bytes = resp.read()
            self.assertGreater(len(audio_bytes), 44)
            self.assertEqual(audio_bytes[:4], b"RIFF")


if __name__ == "__main__":
    unittest.main()

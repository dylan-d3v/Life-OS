# Life-OS
Contexto Maestro: 
Proyecto "Life OS &amp; Asistente IA" Visión General del Proyecto El objetivo principal es construir un ecosistema integral de productividad personal (un "Life OS" o Segundo Cerebro) que combine una aplicación de software central con un dispositivo de hardware satélite. El sistema permitirá gestionar tareas, notas, calendario, finanzas y proyectos a largo plazo. Además, interactuará con un asistente de IA de bolsillo (hardware) capaz de crear, leer, editar y eliminar información mediante comandos de voz.

Contexto Específico: Fases y Componentes

1. El Software (Fase 1 - MVP)

Plataforma: Aplicación nativa para Windows, con el objetivo de ser migrada a dispositivos móviles en el futuro. Se utilizará Flutter (o .NET MAUI) como framework principal por su capacidad multiplataforma.

Módulos Core:

Gestor de tareas (por hacer, hechas, fechas límite).

Sistema de notas de uso diario (apuntes, ideas).

Calendario integrado (eventos).

Gestor de finanzas (ingresos y egresos).

Gestor de proyectos (vinculando notas y tareas a metas específicas).

1. Arquitectura y Privacidad (El Enfoque Híbrido)

El Problema: Quiero privacidad absoluta (100% local), pero mi laptop (Intel i7, 8GB RAM, sin GPU dedicada) no tiene recursos para correr IA localmente con fluidez. Además, si la base de datos es 100% local, el asistente de hardware no funcionará cuando la laptop esté apagada.

La Solución: Una arquitectura Cloud-Híbrida con Cifrado de Extremo a Extremo (E2EE).

Backend: Supabase o Firebase (para que esté siempre encendido y accesible para el hardware).

Privacidad: La aplicación de Windows encriptará todos los datos personales de forma local antes de enviarlos a la nube. El servidor solo almacenará cadenas de texto cifradas ilegibles.

1. El Hardware (Fase 2 - Asistente de Bolsillo)

Inspiración: Basado en el concepto del video de YouTube de Huy Vector ("Building a Tiny Pocket AI Assistant" - https://youtu.be/25RGnr407PM).

Componentes Clave: Un microcontrolador ESP32 (ej. Adafruit HUZZAH32) con batería recargable, micrófono I2S y un pequeño altavoz.

Función: Estará conectado por Wi-Fi. Graba mi voz, la envía a la nube para procesarla y recibe una respuesta de audio. Podrá gestionar mis notas y tareas sin necesidad de que mi computadora esté encendida.

1. Inteligencia Artificial y Lógica Lógica (Kev / Jev)

Toma de Decisiones: En lugar de un LLM conversacional que pueda "alucinar", el cerebro de las acciones utilizará la lógica de Jev / Kev (modelos de TypeSafe AI basados en Qwen, orientados a la toma de decisiones estructuradas).

Flujo: El audio se pasa a texto -&gt; Kev analiza el texto para extraer la intención estructurada (ej. {"acción": "crear\_tarea", "contenido": "comprar pan"}) -&gt; Se ejecuta la acción en la base de datos (Supabase) -&gt; Un modelo de Texto-a-Voz (TTS) me confirma la acción.

Implementación a corto plazo: Dado mi hardware actual, este flujo se simulará inicialmente usando una API rápida en la nube (ej. Groq). A futuro, se planea alojar el cerebro de Kev localmente en una Raspberry Pi o Mini PC dedicada.

Instrucción para la IA en este cuaderno: He subido a este cuaderno varias fuentes de información (documentación de Kev/Jev, el video de referencia del ESP32, guías de Flutter y arquitectura). Por favor, revisa estas fuentes y confirma que entiendes este contexto general y específico. Una vez lo confirmes, te pediré el diseño del primer esquema de base de datos para la aplicación de Windows.

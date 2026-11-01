#pragma once

#include <Arduino.h>
#include "config.h"

/**
 * =============================================================================
 * Button Manager - Gestor de Botón Push-to-Talk con Antirrebote (Debounce)
 * =============================================================================
 * Controla la lectura del pulsador de hardware configurado como INPUT_PULLUP
 * (activo en nivel bajo / LOW), detecta transiciones de presión, soltado
 * y calcula el tiempo sostenido para modo Push-to-Talk.
 */
class ButtonManager {
public:
    explicit ButtonManager(uint8_t pin = PIN_BUTTON_PTT, uint32_t debounceMs = BUTTON_DEBOUNCE_MS);

    /**
     * Inicializa el pin del microcontrolador con resistencia pull-up interna.
     */
    void begin();

    /**
     * Actualiza el estado del botón. Debe invocarse en cada iteración de loop().
     */
    void update();

    /**
     * Retorna true de forma continua mientras el botón se mantenga presionado.
     */
    bool isPressed() const { return _isPressed; }

    /**
     * Retorna true únicamente en el ciclo exacto donde el botón pasó de soltado a presionado.
     */
    bool wasPressed();

    /**
     * Retorna true únicamente en el ciclo exacto donde el botón pasó de presionado a soltado.
     */
    bool wasReleased();

    /**
     * Tiempo en milisegundos que el botón ha permanecido presionado en la sesión actual.
     */
    uint32_t getHoldDurationMs() const;

private:
    uint8_t _pin;
    uint32_t _debounceMs;

    bool _rawState;
    bool _debouncedState;
    bool _lastDebouncedState;
    bool _isPressed;

    bool _wasPressedEvent;
    bool _wasReleasedEvent;

    unsigned long _lastDebounceTime;
    unsigned long _pressStartTime;
};


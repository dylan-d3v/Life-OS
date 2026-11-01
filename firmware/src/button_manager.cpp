#include "button_manager.h"

ButtonManager::ButtonManager(uint8_t pin, uint32_t debounceMs)
    : _pin(pin),
      _debounceMs(debounceMs),
      _rawState(HIGH),
      _debouncedState(HIGH),
      _lastDebouncedState(HIGH),
      _isPressed(false),
      _wasPressedEvent(false),
      _wasReleasedEvent(false),
      _lastDebounceTime(0),
      _pressStartTime(0) {
}

void ButtonManager::begin() {
    pinMode(_pin, INPUT_PULLUP);
    _rawState = digitalRead(_pin);
    _debouncedState = _rawState;
    _lastDebouncedState = _rawState;
    _isPressed = (_debouncedState == LOW);
}

void ButtonManager::update() {
    bool currentReading = digitalRead(_pin);

    // Si la lectura cambió respecto al último estado crudo, reinicia el temporizador de antirrebote
    if (currentReading != _rawState) {
        _lastDebounceTime = millis();
        _rawState = currentReading;
    }

    // Si ha transcurrido el tiempo de debounce establecido
    if ((millis() - _lastDebounceTime) >= _debounceMs) {
        if (currentReading != _debouncedState) {
            _debouncedState = currentReading;

            // Transición a presionado (HIGH -> LOW con INPUT_PULLUP)
            if (_debouncedState == LOW && _lastDebouncedState == HIGH) {
                _isPressed = true;
                _wasPressedEvent = true;
                _pressStartTime = millis();
            }
            // Transición a soltado (LOW -> HIGH)
            else if (_debouncedState == HIGH && _lastDebouncedState == LOW) {
                _isPressed = false;
                _wasReleasedEvent = true;
            }

            _lastDebouncedState = _debouncedState;
        }
    }
}

bool ButtonManager::wasPressed() {
    if (_wasPressedEvent) {
        _wasPressedEvent = false;
        return true;
    }
    return false;
}

bool ButtonManager::wasReleased() {
    if (_wasReleasedEvent) {
        _wasReleasedEvent = false;
        return true;
    }
    return false;
}

uint32_t ButtonManager::getHoldDurationMs() const {
    if (!_isPressed) {
        return 0;
    }
    return (uint32_t)(millis() - _pressStartTime);
}


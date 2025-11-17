#include <Arduino.h>

void setup() {
    pinMode(LED_BUILTIN, OUTPUT);   // встроенный светодиод (D13 на Nano)
}

void loop() {
    digitalWrite(LED_BUILTIN, HIGH);
    delay(100);
    digitalWrite(LED_BUILTIN, LOW);
    delay(100);
}

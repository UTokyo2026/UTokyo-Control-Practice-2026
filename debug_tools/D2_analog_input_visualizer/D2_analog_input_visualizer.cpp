#include "mbed.h"

// ---------- Analog Inputs ----------
AnalogIn ch1(p16);
AnalogIn ch2(p17);
AnalogIn ch3(p19);
AnalogIn ch4(p20);

// ---------- Serial ----------
Serial pc(USBTX, USBRX);

// ---------- Frame header ----------
#define FRAME_H1 0xAA
#define FRAME_H2 0x55

// ---------- helper: 0.0~1.0 -> 0~255 ----------
static inline uint8_t float_to_u8(float x) {
    if (x < 0.0f) x = 0.0f;
    if (x > 1.0f) x = 1.0f;
    return (uint8_t)(x * 255.0f + 0.5f);
}

int main() {
    pc.baud(115200);
    wait(1);

    while (1) {
        float v1 = ch1.read();
        float v2 = ch2.read();
        float v3 = ch3.read();
        float v4 = ch4.read();

        // ---- frame ----
        pc.putc(FRAME_H1);
        pc.putc(FRAME_H2);

        pc.putc(float_to_u8(v1));   // CH1
        pc.putc(float_to_u8(v2));   // CH2
        pc.putc(float_to_u8(v3));   // CH3
        pc.putc(float_to_u8(v4));   // CH4

        wait_ms(5);   // ~200 Hz
    }
}

#include "mbed.h"

// Sampling frequency
#define SAMP_FREQ 2000.0f
// Motor voltage limit (V_motor = 3.3 * v_out * 4)
#define VLIMIT 0.1f
// Motor offset voltage
#define VOFFSET 0.0f
// Feedback gains (Arbitrary Unit)
#define KP 1.0f
#define KD 0.0f

// Frame header (2 bytes)
#define FRAME_H1 0xAA
#define FRAME_H2 0x55

// Define LEDs
PwmOut led_blink(LED1);             // Blink at 1 Hz during operation
PwmOut led_v_over(LED2);            // Indicate voltage saturation
PwmOut led_v_forward(LED3);         // Indicate voltage for forward motion
PwmOut led_v_backward(LED4);        // Indicate voltage for backward motion

// Define motor controls
DigitalOut motor_f(p13);            // Motor forward
DigitalOut motor_r(p14);            // Motor backward
AnalogOut motor_v(p18);             // Motor driving voltage

// Define Photo-diode readings for angle sensor
AnalogIn pd1(p19);
AnalogIn pd2(p20);

Serial pc(USBTX, USBRX);            // Serial communication
Ticker t_int;                       // Interrupt ticker

float brightness = 0.0f;            // Brightness for blinking led_blink
float br_inc = 1.0f / SAMP_FREQ;    // For blinking LED at 1 Hz
float angle = 0.0f, angle_prev = 0.0f;
float v_out = 0.0f;
float v_dir = 1.0f;
float omega = 0.0f;
float f_omega = 0.0f;

// ---- helpers: clamp and pack to uint8 ----
static inline uint8_t clamp_u8(int v) {
    if (v < 0) return 0;
    if (v > 255) return 255;
    return (uint8_t)v;
}

static inline uint8_t float01_to_u8(float x) {
    if (x < 0.0f) x = 0.0f;
    if (x > 1.0f) x = 1.0f;
    // *255 to avoid overflow at exactly 1.0
    return (uint8_t)(x * 255.0f + 0.5f);
}

// map approx [-1, +1] -> [0,255] (center 128)
static inline uint8_t signed1_to_u8(float x) {
    int v = (int)(x * 127.0f + 128.0f + 0.5f);
    return clamp_u8(v);
}

// omega -> [0,255] center 128 with scale factor
static inline uint8_t omega_to_u8(float x, float scale) {
    int v = (int)(x * scale + 128.0f + 0.5f);
    return clamp_u8(v);
}

// Interrupt handler (control loop)
void int0() {
    // Read photo-diodes (0..1)
    float pd1v = pd1.read();
    float pd2v = pd2.read();

    // angle: difference (-1..+1 roughly)
    angle = pd1v - pd2v;

    // omega
    omega = (angle - angle_prev) * SAMP_FREQ;
    angle_prev = angle;

    // filtering omega (currently none)
    f_omega = omega;

    // control output
    v_out = angle * KP + f_omega * KD;
    if (v_out > 0.0f) {
        motor_f = 1;
        motor_r = 0;
        v_dir = 1.0f;
    } else {
        motor_f = 0;
        motor_r = 1;
        v_out *= -1.0f;
        v_dir = -1.0f;
    }

    if (v_out > VLIMIT) {
        v_out = VLIMIT;
        led_v_over = 1;
    } else {
        led_v_over = 0;
    }

    // Motor output
    if (pd1v < 0.02f && pd2v < 0.02f) {   // if not standing, stop the motor
        motor_v = 0;
        led_v_forward = 1;
        led_v_backward = 1;
    } else {
        motor_v = v_out + VOFFSET;
        led_v_forward  = (v_dir > 0 ? v_out * 3.3f : 0.0f);
        led_v_backward = (v_dir < 0 ? v_out * 3.3f : 0.0f);
    }

    // blink LED
    brightness += br_inc;
    if (brightness >= 1.0f) brightness = 0.0f;
    led_blink = brightness;

    // ---- send one frame: [AA 55] + 6 bytes ----
    pc.putc((char)FRAME_H1);
    pc.putc((char)FRAME_H2);

    // CH1..CH6
    pc.putc((char)float01_to_u8(pd1v));            // CH1: pd1
    pc.putc((char)float01_to_u8(pd2v));            // CH2: pd2
    pc.putc((char)signed1_to_u8(angle));           // CH3: angle
    pc.putc((char)omega_to_u8(omega, 10.0f));      // CH4: omega (scaled)
    pc.putc((char)omega_to_u8(f_omega, 10.0f));    // CH5: f_omega (scaled)
    pc.putc((char)128);                            // CH6: reference line
}

int main() {
    // Initializing LED PWM periods and Serial port
    led_blink.period(1.0f / SAMP_FREQ);
    led_v_over.period(1.0f / SAMP_FREQ);
    led_v_forward.period(1.0f / SAMP_FREQ);
    led_v_backward.period(1.0f / SAMP_FREQ);

    pc.baud(230400);

    wait(1);

    // Optional: keep this if your old Processing uses it, but it WILL confuse frame parsing
    // If you switch to frame-header parsing, you can comment this out.
    // pc.printf("12345678");

    // Start Control
    t_int.attach(&int0, 1.0f / SAMP_FREQ);

    // Keep running; do NOT echo back (echo can corrupt framing)
    while (1) {
        // If you want to stop on any received byte, consume without echo:
        if (pc.readable()) {
            (void)pc.getc();
            t_int.detach();
            break;
        }
    }
}

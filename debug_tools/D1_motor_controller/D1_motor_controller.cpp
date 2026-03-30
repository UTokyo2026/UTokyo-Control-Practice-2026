#include "mbed.h"

DigitalOut motor_f(p13);
DigitalOut motor_r(p14);
AnalogOut  motor_v(p18);

Serial pc(USBTX, USBRX);

static void apply_stop() {
    motor_f = 0; motor_r = 0; motor_v = 0.0f;
}

static void apply_fwd(int pct) {
    float duty = pct / 100.0f;
    motor_f = 1; motor_r = 0; motor_v = duty;
}

static void apply_bwd(int pct) {
    float duty = pct / 100.0f;
    motor_f = 0; motor_r = 1; motor_v = duty;
}

int main() {
    pc.baud(115200);
    apply_stop();
    pc.printf("Motor control ready\r\n");
    pc.printf("Commands: F xx | B xx | S\r\n");

    char line[64];
    int idx = 0;

    while (1) {
        if (!pc.readable()) continue;

        char c = pc.getc();
        if (c == '\r') continue;

        if (c == '\n') {
            line[idx] = '\0';
            idx = 0;

            char cmd = 0;
            int value = 0;

            // 支持："F 30" / "B 80" / "S"
            if (sscanf(line, " %c %d", &cmd, &value) >= 1) {
                if (cmd == 'F' || cmd == 'f') {
                    if (value < 0) value = 0;
                    if (value > 100) value = 100;
                    apply_fwd(value);
                    pc.printf("Forward: %d%%\r\n", value);
                } else if (cmd == 'B' || cmd == 'b') {
                    if (value < 0) value = 0;
                    if (value > 100) value = 100;
                    apply_bwd(value);
                    pc.printf("Backward: %d%%\r\n", value);
                } else if (cmd == 'S' || cmd == 's') {
                    apply_stop();
                    pc.printf("Stop\r\n");
                } else {
                    pc.printf("Unknown cmd: %c\r\n", cmd);
                }
            }
        } else {
            if (idx < (int)sizeof(line) - 1) line[idx++] = c;
            else idx = 0; // overflow -> reset
        }
    }
}

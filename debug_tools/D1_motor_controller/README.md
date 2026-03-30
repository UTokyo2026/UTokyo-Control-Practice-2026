# Motor Controller Debug Tool

## Purpose
Interactive tool for testing motor driver circuit and controlling motor speed/direction without modifying code.

## Files

### 1_motor_controller.cpp (mbed program)
**What it does:**
- Receives text commands via USB serial communication
- Controls motor based on received commands
- Provides simple command-line interface for motor testing

**Pin Connections:**
- `p13` (DigitalOut): Motor forward signal → connects to motor driver IN1
- `p14` (DigitalOut): Motor reverse signal → connects to motor driver IN2
- `p18` (AnalogOut): Motor PWM voltage → connects to motor driver VSET
- `USBTX/USBRX`: USB serial communication (built-in)

**Serial Settings:**
- Baud rate: 115200 bps
- Protocol: Text-based ASCII commands

**Commands:**
```
F xx    Forward at xx% duty cycle (0-100)
        Example: "F 50" → forward at 50% speed

B xx    Backward at xx% duty cycle (0-100)
        Example: "B 30" → backward at 30% speed

S       Stop motor
        Example: "S" → stop immediately
```

**How it works:**
1. Program waits for characters from serial port
2. When newline (`\n`) is received, parses the command
3. Extracts command letter (F/B/S) and optional value
4. Applies corresponding motor control:
   - Forward: sets `motor_f=1`, `motor_r=0`, `motor_v=duty`
   - Backward: sets `motor_f=0`, `motor_r=1`, `motor_v=duty`
   - Stop: sets `motor_f=0`, `motor_r=0`, `motor_v=0`
5. Sends confirmation message back via serial

### 1_motor_controller.bin (pre-compiled binary)
**What it is:**
- Compiled executable file for mbed LPC1768
- Contains machine code ready to run on microcontroller

**How to use:**
1. Connect mbed to PC via USB
2. mbed appears as USB drive (e.g., "MBED" or "LPC1768")
3. Drag and drop `1_motor_controller.bin` onto mbed drive
4. LED on mbed flashes during programming
5. Press reset button on mbed to start program

**Why use .bin instead of .cpp:**
- No compilation needed—instant deployment
- Guaranteed to work (already tested and compiled)
- Faster workflow for testing

**When to compile .cpp yourself:**
- Want to change pin assignments
- Need to modify commands or add features
- Want to adjust motor control logic
- Learning how the code works

### 1_motor_controller.pde (Processing visualizer)
**What it does:**
- Provides graphical user interface (GUI) for motor control
- Displays real-time motor status
- Sends commands to mbed via serial

**Features:**
- Sliders for adjusting motor speed (0-100%)
- Buttons for forward/backward/stop
- Real-time display of current motor state
- Visual feedback of PWM duty cycle
- Direction indicator

**How to use:**
1. Install Processing from https://processing.org/download
2. Open `1_motor_controller.pde` in Processing
3. Check serial port name in code (usually auto-detected)
4. Click Run button (▶) to start GUI
5. Use sliders and buttons to control motor

## Usage Workflow

### Quick Start (using .bin file):
1. Flash `1_motor_controller.bin` to mbed
2. Connect motor driver circuit to mbed:
   - p13 → motor driver IN1
   - p14 → motor driver IN2
   - p18 → motor driver VSET
3. Connect motor to driver output
4. Connect power supply
5. Run `1_motor_controller.pde` in Processing
6. Use GUI to test motor

### Advanced (compiling from source):
1. Open Keil Studio Cloud (https://studio.keil.arm.com/)
2. Create new project for mbed LPC1768
3. Import mbed-os library
4. Copy contents of `1_motor_controller.cpp`
5. Compile and download .bin file
6. Flash to mbed as above

## Testing Checklist

Use this tool to verify:
- [ ] Motor rotates forward when commanded
- [ ] Motor rotates backward when commanded
- [ ] Motor speed changes with PWM duty cycle
- [ ] Motor stops completely when commanded
- [ ] No abnormal heating of motor driver IC
- [ ] Power supply voltage remains stable
- [ ] No excessive current draw

## Troubleshooting

**Motor doesn't move:**
- Check battery/power supply is on
- Verify motor driver connections
- Check motor wires are connected
- Ensure mbed is programmed correctly (reset after flashing)

**Motor moves opposite direction:**
- Swap p13 and p14 connections
- Or swap motor wire polarity

**Processing can't connect:**
- Check serial port name in .pde file
- Ensure no other program is using the port
- Try different USB cable (must support data)
- On Windows: look for COM3, COM4, etc.
- On macOS: look for /dev/tty.usbmodem*
- On Linux: look for /dev/ttyACM*

**Motor runs but speed doesn't change:**
- Check p18 (AnalogOut) connection to VSET
- Verify PWM duty cycle is being sent correctly
- Check motor driver power supply

## Technical Details

### Text-Based Protocol
The motor controller uses a simple text-based protocol for human readability:

**Advantages:**
- Easy to test with any serial terminal (PuTTY, screen, etc.)
- Human-readable for debugging
- Simple to parse with `sscanf()`

**Format:**
```
<COMMAND> <VALUE>\n
```
- Commands are single letters (F/B/S)
- Value is optional integer (0-100 for F/B)
- Newline terminates command

**Example transmission:**
```
F 50\n    → Forward 50%
B 30\n    → Backward 30%
S\n       → Stop
```

### Motor Control Logic

**Forward motion:**
```cpp
motor_f = 1;      // Enable forward
motor_r = 0;      // Disable reverse
motor_v = duty;   // Set PWM duty cycle
```

**Backward motion:**
```cpp
motor_f = 0;      // Disable forward
motor_r = 1;      // Enable reverse
motor_v = duty;   // Set PWM duty cycle
```

**Stop:**
```cpp
motor_f = 0;      // Disable forward
motor_r = 0;      // Disable reverse
motor_v = 0.0f;   // Zero voltage
```

### PWM Voltage Output
- `motor_v` is AnalogOut (0.0 to 1.0)
- 0.0 = 0V, 1.0 = 3.3V
- Motor driver amplifies this: V_motor = 3.3V × motor_v × 4
- Example: motor_v = 0.5 → V_motor ≈ 6.6V

## Modifying the Code

### Change pin assignments:
```cpp
DigitalOut motor_f(p21);  // Change from p13 to p21
DigitalOut motor_r(p22);  // Change from p14 to p22
// Note: p18 is the only AnalogOut, cannot change
```

### Add new commands:
```cpp
else if (cmd == 'T' || cmd == 't') {
    // Test mode: alternate forward/backward
    apply_fwd(50);
    wait(1);
    apply_bwd(50);
    wait(1);
    apply_stop();
}
```

### Change baud rate:
```cpp
pc.baud(9600);  // Change from 115200 to 9600
```
(Must also change in Processing .pde file)

## Safety Notes

⚠️ **Important:**
- Always test with low duty cycles first (10-20%)
- Monitor motor driver temperature
- Ensure power supply can provide sufficient current
- Disconnect motor when not testing
- Turn off power between tests to save battery

## See Also
- Main README: `../README.md`
- mbed Serial API: https://os.mbed.com/docs/mbed-os/latest/apis/serial-uart-apis.html
- DRV8832 Datasheet: See appendix in main document

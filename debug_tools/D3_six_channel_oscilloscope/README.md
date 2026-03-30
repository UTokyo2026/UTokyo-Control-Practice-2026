# Six-Channel Oscilloscope Debug Tool

## Purpose
Comprehensive real-time monitoring tool for the complete inverted pendulum control system. Displays 6 channels of data simultaneously, essential for tuning control parameters and debugging feedback control.

## Files

### 3_six_channel_oscilloscope.cpp (mbed program)
**What it does:**
- Implements complete PD (Proportional-Derivative) control loop
- Reads angle sensors (2 photo-interrupters)
- Calculates angle and angular velocity
- Controls motor based on feedback
- Transmits 6 channels of data at 2000 Hz via serial
- Provides real-time control and monitoring

**Pin Connections:**
- `p13` (DigitalOut): Motor forward signal
- `p14` (DigitalOut): Motor reverse signal
- `p18` (AnalogOut): Motor PWM voltage
- `p19` (AnalogIn): Photo-interrupter 1 (angle sensor)
- `p20` (AnalogIn): Photo-interrupter 2 (angle sensor)
- `LED1-LED4`: Status indicators (blink, voltage over, forward, backward)
- `USBTX/USBRX`: USB serial communication (built-in)

**Serial Settings:**
- Baud rate: 230400 bps (higher than other tools due to 2 kHz data rate)
- Protocol: Frame-based binary transmission

**Control Parameters (editable at top of file):**
```cpp
#define SAMP_FREQ 2000.0f   // Sampling frequency (Hz)
#define VLIMIT 0.1f         // Motor voltage limit (0.0-1.0)
#define VOFFSET 0.0f        // Motor offset voltage
#define KP 1.0f             // Proportional gain
#define KD 0.0f             // Derivative gain
```

**Data Frame Format:**
```
[0xAA] [0x55] [CH1] [CH2] [CH3] [CH4] [CH5] [CH6]
 ^^^^   ^^^^   ^^^   ^^^   ^^^   ^^^   ^^^   ^^^
Header Header Data  Data  Data  Data  Data  Data
(2 bytes)     (6 bytes, each 0-255)
```

**6 Data Channels:**
1. **CH1**: Photo-interrupter 1 output (0.0-1.0 → 0-255)
2. **CH2**: Photo-interrupter 2 output (0.0-1.0 → 0-255)
3. **CH3**: Angle (pd1 - pd2, centered at 128)
4. **CH4**: Angular velocity ω (scaled, centered at 128)
5. **CH5**: Filtered angular velocity (scaled, centered at 128)
6. **CH6**: Reference line (fixed at 128)

**How the control loop works:**
```
Every 1/2000 second (500 μs):
1. Read sensors (pd1, pd2)
2. Calculate angle = pd1 - pd2
3. Calculate angular velocity = (angle - angle_prev) × SAMP_FREQ
4. Apply optional filtering to angular velocity
5. Calculate control output = KP × angle + KD × filtered_omega
6. Determine motor direction (forward if v_out > 0, else backward)
7. Limit voltage to VLIMIT
8. Apply voltage to motor
9. Update LED indicators
10. Send 6-channel data frame via serial
11. Wait for next interrupt
```

**Safety features:**
- Voltage limiting (VLIMIT) prevents excessive motor speed
- Automatic motor shutoff if both sensors read < 0.02 (pendulum fallen)
- LED indicators show system status
- Can be stopped by sending any character via serial

### 3_six_channel_oscilloscope.bin (pre-compiled binary)
**What it is:**
- Pre-compiled executable with default control parameters
- Ready to flash for immediate testing

**Default parameters:**
- KP = 1.0 (proportional gain)
- KD = 0.0 (derivative gain - initially disabled)
- VLIMIT = 0.1 (10% of maximum voltage)
- SAMP_FREQ = 2000 Hz

**How to use:**
1. Connect mbed to PC via USB
2. Drag and drop `3_six_channel_oscilloscope.bin` onto mbed drive
3. Press reset button on mbed
4. Control loop starts after 1 second delay

**When to compile .cpp yourself:**
- Want to adjust control gains (KP, KD)
- Need to change voltage limit (VLIMIT)
- Want to modify sampling frequency
- Need to add filtering or other control features
- Want to change which data is displayed on each channel

### 3_six_channel_oscilloscope.pde (Processing visualizer)
**What it does:**
- Receives 6-channel data frames from mbed
- Displays data in two 3-channel plots (upper and lower)
- Provides real-time visualization of control system state
- Essential for parameter tuning and debugging

**Display Layout:**
```
┌─────────────────────────────┐
│  Upper Plot (3 channels)    │
│  Red:   CH1 (pd1)           │
│  Green: CH2 (pd2)           │
│  Blue:  CH3 (angle)         │
├─────────────────────────────┤
│  Lower Plot (3 channels)    │
│  Red:   CH4 (omega)         │
│  Green: CH5 (filtered ω)    │
│  Blue:  CH6 (reference)     │
└─────────────────────────────┘
```

**Features:**
- Automatic scrolling time-series display
- Color-coded channels for easy identification
- Frame synchronization using header detection
- Handles high-speed data (2000 frames/second)

**How to use:**
1. Install Processing from https://processing.org/download
2. Open `3_six_channel_oscilloscope.pde` in Processing
3. Verify serial port name in code
4. Click Run button (▶) to start visualization
5. **Important:** Reset mbed after starting Processing to synchronize display
6. Observe system behavior while tuning control parameters

## Usage Workflow

### Initial Setup:
1. **Assemble complete circuit:**
   - Motor driver connected to p13, p14, p18
   - Photo-interrupters connected to p19, p20
   - Power supply connected (battery box)
   - All connections verified

2. **Flash program:**
   - Copy `3_six_channel_oscilloscope.bin` to mbed
   - Press reset button
   - Wait 1 second (idle period)

3. **Start visualizer:**
   - Run `3_six_channel_oscilloscope.pde` in Processing
   - Reset mbed to synchronize display
   - Observe 6-channel display

### Zeroing the Angle Sensor:
1. **Disconnect motor** (to prevent movement during adjustment)
2. Connect USB cable to mbed
3. Reset mbed, turn on battery box within 1 second
4. Hold pendulum vertical by hand
5. Observe CH3 (blue line, upper screen)
6. Should be approximately at center (128)
7. If not centered, adjust sensor bracket angle carefully
8. Repeat until angle reads ~0 (center) when vertical

### Testing with Proportional Control:
1. Turn off battery box, reconnect motor
2. Reset mbed, turn on battery box within 1 second
3. Stand pendulum vertical
4. Control starts after 1 second
5. Observe system response on oscilloscope:
   - CH3 (angle) should stay near center
   - CH4 (omega) shows angular velocity oscillations
   - Motor LEDs show control effort

### Tuning Control Gains:

**Step 1: Adjust KP (Proportional Gain)**
- Start with KP = 1.0, KD = 0.0
- If oscillation is slow (~1-2 Hz): increase KP
- If oscillation is fast and violent (>5 Hz): decrease KP
- Goal: Find KP where oscillation frequency is moderate (~3-4 Hz)

**Step 2: Add KD (Derivative Gain)**
- Once KP is reasonable, add KD gradually
- Start with KD = 0.1, increase slowly
- KD adds damping, reduces oscillation
- Too much KD causes instability (high-frequency noise amplification)
- Goal: Minimize oscillation while maintaining stability

**Step 3: Adjust VLIMIT**
- If motor saturates (LED2 on constantly): increase VLIMIT
- If motor is too aggressive: decrease VLIMIT
- Typical range: 0.05 - 0.2

**Step 4: Add Filtering (if needed)**
- If angular velocity (CH4) is very noisy, add low-pass filter
- Modify code to implement filtering (see below)
- Monitor CH5 (filtered omega) vs CH4 (raw omega)
- Adjust filter cutoff frequency to balance noise vs delay

## Testing Checklist

Use this tool to verify:
- [ ] Sensors read correctly (CH1, CH2 change with angle)
- [ ] Angle calculation is correct (CH3 centered when vertical)
- [ ] Motor responds to angle error (moves to correct tilt)
- [ ] Control loop runs at 2000 Hz (smooth display)
- [ ] No excessive oscillation or instability
- [ ] Voltage limiting works (LED2 indicates saturation)
- [ ] Motor stops when pendulum falls (safety feature)
- [ ] Can achieve stable balancing with tuned gains

## Troubleshooting

**Pendulum moves opposite to tilt (wrong direction):**
- Motor connections reversed
- Turn off power, swap motor wires
- Or swap p13 ↔ p14 connections

**High-frequency vibration (~5+ Hz):**
- KP gain too high
- Decrease KP by 20-50%
- May also indicate mechanical issues (loose connections)

**Slow oscillation, cannot stabilize:**
- KP gain too low
- Increase KP gradually
- Check motor has sufficient power

**Excessive noise in angular velocity:**
- Sensor signal quality issues
- Add low-pass filter to omega
- Check sensor connections and resistor values
- Route wires away from motor power

**Motor saturates constantly (LED2 always on):**
- VLIMIT too low for current gains
- Increase VLIMIT
- Or decrease control gains (KP, KD)

**Display not synchronized:**
- Reset mbed after starting Processing
- Check baud rate matches (230400)
- Verify USB cable quality

**Control loop seems slow or irregular:**
- Check SAMP_FREQ is 2000 Hz
- Ensure no blocking code in interrupt
- Verify timer interrupt is attached correctly

## Technical Details

### Control Algorithm

**PD Control:**
```
u(t) = KP × e(t) + KD × de/dt

where:
  u(t)   = control output (motor voltage)
  e(t)   = error (angle from vertical)
  de/dt  = rate of change of error (angular velocity)
  KP     = proportional gain
  KD     = derivative gain
```

**Implementation:**
```cpp
// Read sensors
float pd1v = pd1.read();
float pd2v = pd2.read();

// Calculate angle (error)
angle = pd1v - pd2v;

// Calculate angular velocity (derivative)
omega = (angle - angle_prev) * SAMP_FREQ;
angle_prev = angle;

// Control output
v_out = angle * KP + omega * KD;

// Apply to motor with direction and limiting
if (v_out > 0.0f) {
    motor_f = 1; motor_r = 0;
} else {
    motor_f = 0; motor_r = 1;
    v_out = -v_out;
}
if (v_out > VLIMIT) v_out = VLIMIT;
motor_v = v_out;
```

### Data Encoding

**Channels 1-2 (sensor readings):**
```cpp
// 0.0-1.0 → 0-255
uint8_t float01_to_u8(float x) {
    if (x < 0.0f) x = 0.0f;
    if (x > 1.0f) x = 1.0f;
    return (uint8_t)(x * 255.0f + 0.5f);
}
```

**Channel 3 (angle, signed):**
```cpp
// -1.0 to +1.0 → 0-255 (centered at 128)
uint8_t signed1_to_u8(float x) {
    int v = (int)(x * 127.0f + 128.0f + 0.5f);
    if (v < 0) return 0;
    if (v > 255) return 255;
    return (uint8_t)v;
}
```

**Channels 4-5 (angular velocity, scaled):**
```cpp
// omega with scale factor → 0-255 (centered at 128)
uint8_t omega_to_u8(float x, float scale) {
    int v = (int)(x * scale + 128.0f + 0.5f);
    if (v < 0) return 0;
    if (v > 255) return 255;
    return (uint8_t)v;
}
```
- Scale factor = 10.0 for typical omega range
- Adjust if omega values are too small or too large

### Interrupt-Based Control

**Why use interrupts?**
- Ensures precise timing (exactly 2000 Hz)
- Control loop runs independently of main program
- No timing drift or jitter

**Ticker setup:**
```cpp
Ticker t_int;
t_int.attach(&int0, 1.0f / SAMP_FREQ);
```
- Calls `int0()` function every 500 μs
- High priority, preempts main loop

**Important:** Keep interrupt handler fast!
- No `printf()` in interrupt (too slow)
- Use `pc.putc()` for single bytes only
- Avoid complex calculations
- Total execution time should be << 500 μs

### LED Indicators

- **LED1 (led_blink)**: Blinks at 1 Hz to show program is running
- **LED2 (led_v_over)**: On when motor voltage is saturated (hitting VLIMIT)
- **LED3 (led_v_forward)**: Brightness proportional to forward voltage
- **LED4 (led_v_backward)**: Brightness proportional to backward voltage

## Modifying the Code

### Change control gains:
```cpp
#define KP 2.5f   // Increase proportional gain
#define KD 0.3f   // Add derivative gain
```

### Add low-pass filter:
```cpp
// At top of file
#define FILTER_ALPHA 0.1f  // Filter coefficient (0-1)

// In int0() function, after calculating omega:
static float omega_filtered = 0.0f;
omega_filtered = FILTER_ALPHA * omega + (1.0f - FILTER_ALPHA) * omega_filtered;
f_omega = omega_filtered;
```

### Change voltage limit:
```cpp
#define VLIMIT 0.2f  // Increase to 20% of max
```

### Modify sampling frequency:
```cpp
#define SAMP_FREQ 1000.0f  // Reduce to 1 kHz
```
(May need to reduce baud rate if data transmission becomes unreliable)

### Add integral control (PID):
```cpp
// At top of file
#define KI 0.1f

// In int0() function
static float integral = 0.0f;
integral += angle / SAMP_FREQ;  // Integrate angle
v_out = angle * KP + f_omega * KD + integral * KI;
```

### Change which data is displayed:
```cpp
// In int0() function, modify the pc.putc() calls:
pc.putc((char)float01_to_u8(motor_v));     // CH1: motor voltage
pc.putc((char)signed1_to_u8(v_out));       // CH2: control output
pc.putc((char)signed1_to_u8(angle));       // CH3: angle
pc.putc((char)omega_to_u8(omega, 10.0f));  // CH4: omega
pc.putc((char)omega_to_u8(f_omega, 10.0f));// CH5: filtered omega
pc.putc((char)128);                        // CH6: reference
```

## Advanced Topics

### Filter Design

**First-order low-pass filter:**
```
y[n] = α × x[n] + (1-α) × y[n-1]

where:
  α = cutoff frequency / sampling frequency
  x[n] = input (current sample)
  y[n] = output (filtered value)
  y[n-1] = previous output
```

**Choosing α:**
- α = 0.1 → cutoff ≈ 200 Hz (strong filtering)
- α = 0.5 → cutoff ≈ 1000 Hz (mild filtering)
- Lower α = more filtering, more delay
- Higher α = less filtering, less delay

**Trade-off:**
- Too much filtering → slow response, instability
- Too little filtering → noise amplification, instability
- Goal: Filter just enough to remove high-frequency noise

### Baud Rate Calculation

**Data rate:**
- 6 bytes per frame + 2 header bytes = 8 bytes/frame
- 2000 frames/second × 8 bytes/frame = 16000 bytes/second
- 16000 bytes/second × 10 bits/byte (UART overhead) = 160000 bps

**Safety margin:**
- Use 230400 bps (1.44× required rate)
- Provides margin for processing delays
- Standard baud rate (well-supported)

**If you need higher sampling rate:**
- Reduce number of channels
- Increase baud rate (460800, 921600)
- Use more efficient encoding (not all platforms support)

### Motor Voltage Calculation

**Output voltage:**
```
V_motor = 3.3V × motor_v × 4 (driver gain)

Examples:
  motor_v = 0.1 → V_motor = 1.32V
  motor_v = 0.2 → V_motor = 2.64V
  motor_v = 1.0 → V_motor = 13.2V (max)
```

**VLIMIT interpretation:**
- VLIMIT = 0.1 → max 1.32V to motor
- VLIMIT = 0.2 → max 2.64V to motor
- Adjust based on battery voltage and motor specs

## Safety Notes

⚠️ **Important:**
- Always test with low gains first (KP = 0.5, KD = 0)
- Start with low VLIMIT (0.05-0.1)
- Hold pendulum when first testing
- Turn off battery box between tests
- Monitor motor driver temperature
- Be ready to catch falling pendulum
- Stop immediately if anything seems wrong

## Performance Tips

1. **Start conservative:** Low gains, low voltage limit
2. **Tune incrementally:** Change one parameter at a time
3. **Use oscilloscope:** Monitor all channels while tuning
4. **Document settings:** Record successful parameter combinations
5. **Test thoroughly:** Verify stability under various conditions

## See Also
- Main README: `../README.md`
- mbed Ticker API: https://os.mbed.com/docs/mbed-os/latest/apis/ticker.html
- PID Control Tutorial: https://en.wikipedia.org/wiki/PID_controller
- Digital Filter Design: https://en.wikipedia.org/wiki/Digital_filter

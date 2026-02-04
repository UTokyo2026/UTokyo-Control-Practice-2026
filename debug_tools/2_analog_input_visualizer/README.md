# Analog Input Visualizer Debug Tool

## Purpose
Real-time visualization of 4 analog input channels. Versatile tool for monitoring any analog sensors including:
- Photo-interrupters (angle sensors)
- Encoder signals (can use CH1/CH2 for encoder A/B)
- Potentiometers
- Voltage sensors
- Any 0-3.3V analog signals

## Files

### 2_analog_input_visualizer.cpp (mbed program)
**What it does:**
- Reads 4 analog input channels at approximately 200 Hz
- Converts analog readings (0.0-1.0) to 8-bit values (0-255)
- Transmits data via USB serial using frame-based protocol
- Universal tool for any analog sensors: photo-interrupters, encoders, potentiometers, etc.

**Pin Connections:**
- `p16` (AnalogIn): Channel 1 - General analog input (can be used for encoder A)
- `p17` (AnalogIn): Channel 2 - General analog input (can be used for encoder B)
- `p19` (AnalogIn): Channel 3 - General analog input (typically photo-interrupter 1 for angle)
- `p20` (AnalogIn): Channel 4 - General analog input (typically photo-interrupter 2 for angle)
- `USBTX/USBRX`: USB serial communication (built-in)

**Serial Settings:**
- Baud rate: 115200 bps
- Protocol: Frame-based binary transmission

**Data Frame Format:**
```
[0xAA] [0x55] [CH1] [CH2] [CH3] [CH4]
 ^^^^   ^^^^   ^^^   ^^^   ^^^   ^^^
Header Header Data  Data  Data  Data
(2 bytes)     (4 bytes, each 0-255)
```

**Sampling Rate:**
- Approximately 200 Hz (5 ms delay between frames)
- Fast enough for pendulum motion tracking
- Slow enough for reliable serial transmission

**How it works:**
1. Main loop reads 4 analog inputs using `AnalogIn.read()`
2. Each reading (float 0.0-1.0) is converted to uint8 (0-255)
3. Frame header (0xAA 0x55) is sent first
4. Four data bytes are sent in order (CH1-CH4)
5. 5 ms delay before next frame
6. Processing searches for header pattern to synchronize

### 2_analog_input_visualizer.bin (pre-compiled binary)
**What it is:**
- Pre-compiled executable for mbed LPC1768
- Ready to flash without compilation

**How to use:**
1. Connect mbed to PC via USB
2. Drag and drop `2_analog_input_visualizer.bin` onto mbed drive
3. Press reset button on mbed
4. Program starts transmitting analog input data

**When to compile .cpp yourself:**
- Want to change sampling rate (modify `wait_ms(5)`)
- Need different pin assignments
- Want to add more channels
- Need to modify data scaling or filtering

### 2_analog_input_visualizer.pde (Processing visualizer)
**What it does:**
- Receives data frames from mbed via serial
- Displays 4-channel real-time waveforms
- Can calculate and display pendulum angle (if using photo-interrupters)
- Can show encoder signals (if using encoder inputs)
- Flexible visualization for any analog sensor data

**Features:**
- 4 synchronized time-series plots
- Color-coded channels for easy identification
- Automatic scaling and scrolling
- Frame synchronization using header detection
- Visual pendulum angle indicator (graphical representation)

**How to use:**
1. Install Processing from https://processing.org/download
2. Open `2_analog_input_visualizer.pde` in Processing
3. Verify serial port name in code (usually auto-detected)
4. Click Run button (▶) to start visualization
5. Reset mbed to synchronize display
6. Manually move pendulum to observe sensor response

## Usage Workflow

### Quick Start:
1. **Connect sensors to mbed:**
   - Photo-interrupter 1 output → p19
   - Photo-interrupter 2 output → p20
   - Sensor power: 3.3V (not 5V!)
   - Install pull-up resistors (typically 1kΩ - 12kΩ)

2. **Flash program:**
   - Copy `angle_sensor_visualizer.bin` to mbed USB drive
   - Press reset button

3. **Run visualizer:**
   - Open `angle_sensor_visualizer.pde` in Processing
   - Click Run (▶)
   - Reset mbed to synchronize

4. **Test sensors:**
   - Manually rotate pendulum slowly
   - Observe waveforms change
   - Verify angle calculation is correct
   - Check for noise or signal issues

## Testing Checklist

Use this tool to verify:
- [ ] Sensor outputs change as pendulum moves
- [ ] Both sensors produce clean signals (not too noisy)
- [ ] Angle calculation corresponds to actual position
- [ ] Sensors detect full range of motion (±30° or more)
- [ ] No signal saturation (outputs not stuck at 0 or 255)
- [ ] Sensor alignment is mechanically correct
- [ ] No interference from motor or other circuits

## Troubleshooting

**No data displayed:**
- Check serial port name in .pde file
- Reset mbed after starting Processing
- Verify USB cable supports data (not power-only)
- Check baud rate matches (115200)

**Noisy or erratic signals:**
- Check sensor power supply (should be stable 3.3V)
- Verify pull-up resistors are installed
- Route sensor wires away from motor power lines
- Check for loose connections on breadboard
- Try different resistor values (1kΩ - 12kΩ range)

**Sensor output saturated (stuck at 0 or 255):**
- Resistor value too high or too low
- For high output (255): decrease resistor value
- For low output (0): increase resistor value
- Typical range: 3kΩ - 10kΩ for photo-interrupters

**Angle calculation seems wrong:**
- Check sensor mechanical alignment
- Verify sensors are 90° apart (or appropriate spacing)
- Adjust sensor mounting bracket carefully
- Ensure encoder disk/slit is properly positioned

**Processing crashes or freezes:**
- Close and restart Processing
- Check for serial port conflicts
- Ensure mbed is properly programmed
- Try different USB port

## Technical Details

### Frame-Based Protocol

**Why use frame headers?**
- Serial data is a continuous stream of bytes
- Without headers, impossible to know where each frame starts
- Headers (0xAA 0x55) are unlikely to appear in normal data
- Processing searches for this pattern to synchronize

**Synchronization algorithm:**
```
1. Read byte from serial
2. If byte == 0xAA:
   3. Read next byte
   4. If next byte == 0x55:
      5. Read 4 data bytes (CH1-CH4)
      6. Display data
   7. Else: go back to step 1
8. Else: go back to step 1
```

**Data encoding:**
```cpp
// Convert float (0.0-1.0) to uint8 (0-255)
uint8_t float_to_u8(float x) {
    if (x < 0.0f) x = 0.0f;
    if (x > 1.0f) x = 1.0f;
    return (uint8_t)(x * 255.0f + 0.5f);
}
```
- Analog reading: 0.0 → 0V, 1.0 → 3.3V
- Transmitted value: 0 → 0V, 255 → 3.3V
- Resolution: 3.3V / 255 ≈ 13 mV per step

### Angle Calculation

For two photo-interrupters measuring pendulum angle:

**Differential measurement:**
```
angle = sensor1 - sensor2
```
- When pendulum is vertical: sensor1 ≈ sensor2 → angle ≈ 0
- When pendulum tilts right: sensor1 > sensor2 → angle > 0
- When pendulum tilts left: sensor1 < sensor2 → angle < 0

**Angular velocity:**
```
omega = (angle - angle_prev) × sampling_frequency
```
- Derivative approximation using finite difference
- Sampling frequency ≈ 200 Hz
- Units: arbitrary (proportional to rad/s)

### Photo-Interrupter Operation

**How it works:**
1. LED emits infrared light
2. Light reflects off encoder disk (white/reflective areas)
3. Phototransistor detects reflected light
4. Output voltage proportional to light intensity
5. Bright reflection → high voltage (near 3.3V)
6. Dark area → low voltage (near 0V)

**Pull-up resistor:**
```
3.3V ──┬── Resistor ──┬── Phototransistor ── GND
       │              │
       └─ To mbed pin ┘
```
- Resistor value determines sensitivity
- Higher R → higher voltage, more sensitive, may saturate
- Lower R → lower voltage, less sensitive, more noise-resistant
- Typical: 3kΩ - 10kΩ for this application

## Modifying the Code

### Change sampling rate:
```cpp
wait_ms(5);   // 200 Hz → change to wait_ms(10) for 100 Hz
```

### Add more channels:
```cpp
AnalogIn ch5(p15);  // Add new channel

// In main loop:
float v5 = ch5.read();
pc.putc(float_to_u8(v5));  // Send after CH4
```
(Must also update Processing to read 5 bytes)

### Change pin assignments:
```cpp
AnalogIn ch1(p15);  // Change from p16 to p15
AnalogIn ch2(p16);  // Change from p17 to p16
// etc.
```

### Add filtering:
```cpp
// Simple moving average filter
float v1_filtered = 0.9f * v1_prev + 0.1f * v1;
v1_prev = v1_filtered;
```

### Change baud rate:
```cpp
pc.baud(230400);  // Change from 115200 to 230400
```
(Must also change in Processing .pde file)

## Sensor Alignment Procedure

1. **Mechanical setup:**
   - Mount sensors on L-bracket
   - Position encoder disk between sensor gaps
   - Ensure disk can rotate freely without rubbing

2. **Electrical verification:**
   - Power on circuit (battery box or USB)
   - Run visualizer
   - Check all channels show reasonable values (not 0 or 255)

3. **Alignment test:**
   - Hold pendulum vertical
   - Observe CH3 and CH4 waveforms
   - Both should be approximately equal when vertical
   - Adjust sensor bracket angle if needed

4. **Range test:**
   - Rotate pendulum through full range (±30° or more)
   - Verify sensors respond throughout range
   - Check for dead zones or saturation

5. **Noise check:**
   - Hold pendulum still
   - Observe signal stability
   - Some noise is acceptable, but excessive noise indicates issues

## Safety Notes

⚠️ **Important:**
- Use 3.3V for sensor power (not 5V) - mbed inputs are 3.3V logic
- Do not force encoder disk - it should rotate freely
- Be gentle with universal board - it breaks easily
- Route sensor wires away from motor power lines
- Check connections before powering on

## See Also
- Main README: `../README.md`
- mbed AnalogIn API: https://os.mbed.com/docs/mbed-os/latest/apis/analogin.html
- Processing Serial Library: https://processing.org/reference/libraries/serial/
- Photo-interrupter datasheet: See appendix in main document (TPR-105F)

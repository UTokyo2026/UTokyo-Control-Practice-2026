# Wheeled Inverted Pendulum - Course Materials

Course materials for the Wheeled Inverted Pendulum practical exercise at the University of Tokyo, Department of Precision Engineering.

## 📁 Contents

### 📄 Lecture notes (English)
- **text2026_en.pdf** – Full lecture text (English) for the Wheeled Inverted Pendulum exercise. Same content as the printed handout; all appendix PDFs are embedded. Update this file from the LaTeX build when you release a new version (see “Keeping the PDF in sync” below).

### 🛠️ debug_tools/
Debugging and visualization tools with complete documentation:

- **1_motor_controller/** - Interactive motor testing tool
- **2_analog_input_visualizer/** - 4-channel analog input visualization
- **3_six_channel_oscilloscope/** - Complete inverted pendulum control program with 6-channel real-time visualization

Each tool includes:
- `.cpp` - mbed source code
- `.bin` - Pre-compiled binary (ready to flash)
- `.pde` - Processing visualization program
- `README.md` / `README.pdf` - Complete documentation

### 📚 appendix/
All appendix materials (same as in the lecture notes):

- **Datasheets:** `AE-drv8832_a.pdf`, `Circuit_diagram.pdf`, `LD1117V33.pdf`, `RE280ra.pdf`, `TPR-105f.pdf`
- `parts_list.pdf` - Parts list
- `processing_oscilloscope_manual.pdf` - Processing installation and oscilloscope manual

### 📊 matlab_simulink/
MATLAB/Simulink models for simulation and controller design (to be added)

### 🎥 video/
Demonstration videos of working inverted pendulum

## 🚀 Quick Start

### Using the Complete Control Program

1. **Flash to mbed:**
   ```
   debug_tools/3_six_channel_oscilloscope/3_six_channel_oscilloscope.bin
   ```
   Drag and drop this file to your mbed USB drive.

2. **Run visualization:**
   Open `3_six_channel_oscilloscope.pde` in Processing and click Run.

3. **Reset mbed** to synchronize the display.

### Understanding the Code

Open `3_six_channel_oscilloscope.cpp` to see the complete implementation:
- Lines 3-11: Control parameters (KP, KD, VLIMIT, etc.)
- Lines 70-132: Main control loop (PD control algorithm)
- Lines 134-161: Initialization and startup

### Adjusting Parameters

Edit the `#define` values at the top of `3_six_channel_oscilloscope.cpp`:

```cpp
#define SAMP_FREQ 2000.0f  // Sampling frequency (Hz)
#define VLIMIT 0.1f        // Motor voltage limit (0-1)
#define VOFFSET 0.0f       // Friction compensation
#define KP 1.0f            // Proportional gain
#define KD 0.0f            // Derivative gain
```

Then recompile in Keil Studio Cloud and flash the new `.bin` file.

## 📖 Documentation

Detailed documentation is available in the `debug_tools/` folder:

- **Main README:** `debug_tools/README.md` - Overview of all tools
- **Tool-specific READMEs:** Each tool has its own detailed documentation

All READMEs are available in both Markdown (`.md`) and PDF (`.pdf`) formats.

## 🔧 Requirements

### Hardware
- mbed LPC1768 microcontroller
- DRV8832 motor driver module
- RE-280RA DC motor
- TPR-105F photo-interrupters (×2)
- LD1117V33 voltage regulator
- Battery pack and other components (see circuit diagram)

### Software
- [Keil Studio Cloud](https://studio.keil.arm.com/) - For compiling mbed programs
- [Processing](https://processing.org/download) - For visualization tools
- [MATLAB/Simulink](https://www.mathworks.com/) - For simulation (optional)

## 📝 License

These materials are provided for educational purposes as part of the University of Tokyo Precision Engineering practical exercise course.

## 🎓 Course Information

- **Course:** Practical Exercise in Precision Engineering
- **Institution:** University of Tokyo, Department of Precision Engineering
- **Academic Year:** 2026 S1S2

## 📧 Support

For questions or issues:
1. Check the README files in `debug_tools/`
2. Review the circuit diagram in `appendix/`
3. Consult the course lecture notes
4. Ask your instructor or TA

## 🔗 Related Resources

- [mbed Documentation](https://os.mbed.com/docs/)
- [Processing Documentation](https://processing.org/reference/)
- [DRV8832 Datasheet](https://www.ti.com/product/DRV8832)

---

**Last Updated:** February 2026  
**Version:** 2026.1

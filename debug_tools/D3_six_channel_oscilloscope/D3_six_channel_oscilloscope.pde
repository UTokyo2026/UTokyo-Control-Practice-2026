// ============================================================
// 6ch Serial Plotter with Resizable UI (Processing)
// Frame: [0xAA 0x55] + 6 bytes
// UI: Port dropdown + Connect + Start/Pause + Arm Save
// New: Drag the divider to resize UI/plot ratio
// ============================================================

import processing.serial.*;
import java.io.File;

// --------------------------- Constants ---------------------------
final int COMSPEED = 230400;

// Window / plot layout
final int WIN_W = 1500;
int plotH = 256;                 // derived from window height and UI_H
final int BORDER = 10;
int UI_H = 90;                   // resizable

// Divider (resizable handle)
boolean resizing = false;
final int DIVIDER_THICKNESS = 6;
final int MIN_UI_H = 60;
final int MIN_PLOT_H = 100;

// Frame header
final int H1 = 0xAA;
final int H2 = 0x55;

// Limit frames processed per draw() to keep UI responsive
final int MAX_FRAMES_PER_DRAW = 300;

// Channels
final int CH = 6;
String[] chName = {
  "CH1 pd1 (0..1)",
  "CH2 pd2 (0..1)",
  "CH3 angle",
  "CH4 omega",
  "CH5 f_omega",
  "CH6 ref"
};

// --------------------------- Serial / State ---------------------------
Serial port = null;
String[] ports = new String[0];
int selectedPort = -1;
boolean dropdownOpen = false;

boolean connected = false;
boolean running = false;

// Arm/save behavior
boolean armedSave = false;
boolean pendingSave = false;

// Save folder
String saveDir;

// Frame parser state
int syncState = 0;               // 0 wait H1, 1 wait H2, 2 payload
int payloadIdx = 0;
int[] frame = new int[CH];

// Plot cursor
int t = 0;

// --------------------------- UI geometry ---------------------------
final int DD_X = 90, DD_Y = 10, DD_W = 420, DD_H = 24;
final int ITEM_H = 22;
final int DD_MAX_VISIBLE = 10;

final int BTN_W = 110, BTN_H = 24;
final int BTN_CONNECT_X = 530, BTN_CONNECT_Y = 10;
final int BTN_RUN_X     = 650, BTN_RUN_Y     = 10;
final int BTN_ARM_X     = 770, BTN_ARM_Y     = 10;

// ============================================================
// Setup / Draw
// ============================================================

void setup() {
  pixelDensity(1);

  // Initial window size (height stays constant; UI_H changes redistribute space)
  int winH = 256 * 2 + BORDER + UI_H;
  surface.setSize(WIN_W, winH);

  textSize(12);

  // Create save folder under sketch
  saveDir = sketchPath("captures");
  File d = new File(saveDir);
  if (!d.exists()) d.mkdirs();

  refreshPorts();
  recomputePlotHeight();
  redrawAll();
}

void draw() {
  // If resizing, recompute layout and clear plot area
  if (resizing) {
    handleResize();
  }

  // Draw UI + divider each frame
  drawUI();
  drawResizeDivider();

  // Avoid plotting over dropdown list area
  if (dropdownOpen) {
    doPendingSaveIfAny();
    return;
  }

  // Need connected + running to plot
  if (!connected || !running || port == null) {
    doPendingSaveIfAny();
    return;
  }

  // New sweep: clear plot area
  if (t == 0) redrawPlotArea();

  // Read and plot frames
  readAndPlotFrames();

  // Deferred save at end of draw()
  doPendingSaveIfAny();
}

// ============================================================
// Resizing logic
// ============================================================

void drawResizeDivider() {
  int divY = UI_H - DIVIDER_THICKNESS / 2;

  boolean mouseOver = (mouseY >= divY && mouseY <= divY + DIVIDER_THICKNESS);

  noStroke();
  if (resizing) fill(100, 150, 255);
  else if (mouseOver) fill(150);
  else fill(200);

  rect(0, divY, width, DIVIDER_THICKNESS);

  // Handle indicators
  stroke(255);
  strokeWeight(2);
  int cy = divY + DIVIDER_THICKNESS / 2;
  line(width/2 - 20, cy - 2, width/2 + 20, cy - 2);
  line(width/2 - 20, cy + 2, width/2 + 20, cy + 2);

  // Cursor hint
  if (mouseOver || resizing) cursor(HAND);
  else cursor(ARROW);
}

void handleResize() {
  // Constrain UI height so plots always have enough space
  int maxUI = height - (MIN_PLOT_H * 2) - BORDER;
  UI_H = constrain(mouseY, MIN_UI_H, maxUI);

  recomputePlotHeight();

  // Redraw everything when resizing
  background(255);
  redrawPlotArea();
}

void recomputePlotHeight() {
  plotH = (height - UI_H - BORDER) / 2;
  plotH = max(plotH, MIN_PLOT_H);
}

// ============================================================
// Serial parsing & plotting
// ============================================================

void readAndPlotFrames() {
  int framesThisDraw = 0;

  while (port.available() > 0 && framesThisDraw < MAX_FRAMES_PER_DRAW) {
    int b = port.read() & 0xFF;

    if (syncState == 0) {
      if (b == H1) syncState = 1;
    } else if (syncState == 1) {
      if (b == H2) {
        syncState = 2;
        payloadIdx = 0;
      } else if (b == H1) {
        syncState = 1; // AA AA 55 case
      } else {
        syncState = 0;
      }
    } else { // syncState == 2, reading payload
      if (payloadIdx < CH) {
        frame[payloadIdx++] = b;
      } else {
        // Safety reset
        resetParser();
        continue;
      }

      if (payloadIdx >= CH) {
        resetParser();

        // Plot this frame
        for (int ch = 0; ch < CH; ch++) plotData(frame[ch], ch);

        t++;
        framesThisDraw++;

        // End of sweep
        if (t >= width) {
          t = 0;
          if (armedSave) pendingSave = true;
          break;
        }
      }
    }
  }
}

void plotData(int v, int c) {
  // Reuse 3 colors across 6 channels (like original)
  if (c % 3 == 0) stroke(255, 0, 0);
  if (c % 3 == 1) stroke(0, 255, 0);
  if (c % 3 == 2) stroke(0, 0, 255);
  strokeWeight(2);

  int block = c / 3; // 0 top plot, 1 bottom plot
  float y = plotH - map(v, 0, 255, 0, plotH)
            + block * (plotH + BORDER)
            + UI_H;

  point(t, y);
}

// ============================================================
// Save helper (deferred save at end of draw)
// ============================================================

void doPendingSaveIfAny() {
  if (!pendingSave) return;

  // Timestamp filename to avoid overwriting
  String out = saveDir + File.separator
               + "data-" + year() + nf(month(), 2) + nf(day(), 2) + "-"
               + nf(hour(), 2) + nf(minute(), 2) + nf(second(), 2) + ".png";

  println("Saved: " + out);

  // Save whole window (including UI). If you want ONLY plot area, see below.
  save(out);

  // If you want ONLY plot area (no UI), use:
  // PImage img = get(0, UI_H, width, height - UI_H);
  // img.save(out);

  // Auto pause & disarm after saving
  running = false;
  armedSave = false;
  pendingSave = false;

  // IMPORTANT: flush backlog so next Start won't "fast play"
  flushSerial();
}

// ============================================================
// UI drawing
// ============================================================

void drawUI() {
  noStroke();
  fill(245);
  rect(0, 0, width, UI_H - DIVIDER_THICKNESS/2);

  fill(0);
  text("Serial Port:", 10, 27);

  drawDropdown();

  drawButton(BTN_CONNECT_X, BTN_CONNECT_Y, BTN_W, BTN_H,
             "Connect", color(200, 200, 255));

  String runLabel = running ? "Pause" : "Start";
  int runColor = running ? color(255, 210, 210) : color(210, 255, 210);
  drawButton(BTN_RUN_X, BTN_RUN_Y, BTN_W, BTN_H, runLabel, runColor);

  String armLabel = armedSave ? "Armed ✓" : "Arm Save";
  int armColor = armedSave ? color(255, 235, 180) : color(240);
  drawButton(BTN_ARM_X, BTN_ARM_Y, BTN_W, BTN_H, armLabel, armColor);

  fill(60);
  text("Press 'r' to refresh ports | Drag divider to resize", 10, 55);

  fill(0);
  String p = getSelectedPortName();
  String status = connected ? "Connected" : "Disconnected";
  String run = running ? "Running" : "Paused";
  String arm = armedSave ? "ARMED" : "—";
  text("Status: " + status + " | " + run + " | Save: " + arm
       + " | Port: " + (p == null ? "(none)" : p),
       10, 75);
}

void drawDropdown() {
  stroke(60);
  strokeWeight(1);
  fill(255);
  rect(DD_X, DD_Y, DD_W, DD_H, 4);

  fill(0);
  String label = getSelectedPortName();
  if (label == null) label = "(no ports)";
  text(label, DD_X + 8, DD_Y + 17);

  fill(80);
  triangle(DD_X + DD_W - 18, DD_Y + 9,
           DD_X + DD_W - 8,  DD_Y + 9,
           DD_X + DD_W - 13, DD_Y + 16);

  if (!dropdownOpen) return;

  int n = ports.length;
  int visible = min(n, DD_MAX_VISIBLE);
  int listH = visible * ITEM_H;

  stroke(60);
  fill(255);
  rect(DD_X, DD_Y + DD_H, DD_W, listH, 4);

  for (int i = 0; i < visible; i++) {
    int itemY = DD_Y + DD_H + i * ITEM_H;

    // Selected highlight
    if (i == selectedPort) {
      noStroke();
      fill(230);
      rect(DD_X + 1, itemY + 1, DD_W - 2, ITEM_H - 2);
    }

    // Hover highlight
    if (mouseX >= DD_X && mouseX <= DD_X + DD_W &&
        mouseY >= itemY && mouseY < itemY + ITEM_H) {
      noStroke();
      fill(240);
      rect(DD_X + 1, itemY + 1, DD_W - 2, ITEM_H - 2);
    }

    fill(0);
    text(ports[i], DD_X + 8, itemY + 15);
  }
}

void drawButton(int x, int y, int w, int h, String label, int bg) {
  stroke(60);
  strokeWeight(1);
  fill(bg);
  rect(x, y, w, h, 4);

  fill(0);
  float tx = x + (w - textWidth(label)) / 2.0;
  float ty = y + 16;
  text(label, tx, ty);
}

// ============================================================
// Input handling
// ============================================================

void mousePressed() {
  // Divider drag start
  int divY = UI_H - DIVIDER_THICKNESS / 2;
  if (mouseY >= divY && mouseY <= divY + DIVIDER_THICKNESS) {
    resizing = true;
    return;
  }

  // Dropdown toggle
  if (inside(mouseX, mouseY, DD_X, DD_Y, DD_W, DD_H)) {
    dropdownOpen = !dropdownOpen;
    return;
  }

  // Dropdown item click
  if (dropdownOpen) {
    int n = ports.length;
    int visible = min(n, DD_MAX_VISIBLE);
    int listY = DD_Y + DD_H;
    int listH = visible * ITEM_H;

    if (inside(mouseX, mouseY, DD_X, listY, DD_W, listH)) {
      int idx = (mouseY - listY) / ITEM_H;
      if (idx >= 0 && idx < visible) selectedPort = idx;
      dropdownOpen = false;
    } else {
      dropdownOpen = false;
    }
    return;
  }

  // Connect
  if (inside(mouseX, mouseY, BTN_CONNECT_X, BTN_CONNECT_Y, BTN_W, BTN_H)) {
    connectPort();
    return;
  }

  // Start / Pause
  if (inside(mouseX, mouseY, BTN_RUN_X, BTN_RUN_Y, BTN_W, BTN_H)) {
    if (connected && port != null) {
      if (!running) {
        // Start: restart sweep & refresh plot
        t = 0;
        resetParser();
        redrawPlotArea();

        // IMPORTANT: flush backlog so it won't "fast play"
        flushSerial();

        running = true;
      } else {
        running = false;
      }
    }
    return;
  }

  // Arm Save
  if (inside(mouseX, mouseY, BTN_ARM_X, BTN_ARM_Y, BTN_W, BTN_H)) {
    armedSave = !armedSave;
    return;
  }
}

void mouseReleased() {
  resizing = false;
}

void keyPressed() {
  if (key == 'r' || key == 'R') {
    refreshPorts();
    if (selectedPort >= ports.length) selectedPort = ports.length - 1;
    redrawAll();
  }
}

boolean inside(int mx, int my, int x, int y, int w, int h) {
  return mx >= x && mx <= x + w && my >= y && my <= y + h;
}

// ============================================================
// Serial helpers
// ============================================================

void refreshPorts() {
  ports = Serial.list();
  if (ports == null) ports = new String[0];
  selectedPort = (ports.length > 0) ? 0 : -1;

  println("Ports:");
  printArray(ports);
}

String getSelectedPortName() {
  if (ports == null || ports.length == 0) return null;
  if (selectedPort < 0 || selectedPort >= ports.length) return null;
  return ports[selectedPort];
}

void connectPort() {
  closePort();

  String p = getSelectedPortName();
  if (p == null) {
    connected = false;
    running = false;
    return;
  }

  try {
    port = new Serial(this, p, COMSPEED);

    // Flush old bytes immediately after open
    port.clear();
    while (port.available() > 0) port.read();

    connected = true;
    running = false;
    armedSave = false;
    pendingSave = false;

    resetParser();
    t = 0;

    redrawAll();
  } catch (Exception e) {
    println("Failed to open port: " + p);
    println(e);

    closePort();
    connected = false;
    running = false;
  }
}

void closePort() {
  if (port != null) {
    try { port.stop(); } catch (Exception ignored) {}
    port = null;
  }
}

void resetParser() {
  syncState = 0;
  payloadIdx = 0;
}

// Flush backlog bytes so restarting won't "fast-forward"
void flushSerial() {
  if (port == null) return;

  try { port.clear(); } catch (Exception ignored) {}

  int guard = 0;
  while (port.available() > 0 && guard < 200000) {
    port.read();
    guard++;
  }
}

// ============================================================
// Plot area drawing
// ============================================================

void redrawAll() {
  background(255);
  redrawPlotArea();
}

void redrawPlotArea() {
  // Clear plot area only
  noStroke();
  fill(255);
  rect(0, UI_H, width, height - UI_H);

  drawAxes();
  drawLegend(0, UI_H + 20);                          // CH1..CH3
  drawLegend(3, UI_H + plotH + BORDER + 20);         // CH4..CH6
}

void drawAxes() {
  // Divider line between plots
  stroke(128);
  strokeWeight(2);
  line(0, UI_H + plotH, width, UI_H + plotH);

  // Faint horizontal grid
  stroke(200);
  strokeWeight(1);
  for (int i = 1; i < 4; i++) {
    line(0, UI_H + i*(plotH/4), width, UI_H + i*(plotH/4));
    line(0, UI_H + plotH + BORDER + i*(plotH/4),
         width, UI_H + plotH + BORDER + i*(plotH/4));
  }
}

void drawLegend(int startCh, int y) {
  noStroke();
  fill(255, 235);
  rect(8, y - 16, 180, 3*16 + 14, 4);

  for (int i = 0; i < 3; i++) {
    int c = startCh + i;

    if (c % 3 == 0) fill(255, 0, 0);
    if (c % 3 == 1) fill(0, 255, 0);
    if (c % 3 == 2) fill(0, 0, 255);

    rect(14, y + i*16 - 10, 10, 10);

    fill(0);
    text(chName[c], 30, y + i*16);
  }
}

import processing.serial.*;

// ---------------- Serial ----------------
final int BAUD = 115200;
Serial port;
String[] ports = new String[0];
int portIndex = 0;
boolean connected = false;

// ---------------- UI State ----------------
int dutyPct = 30;   // 0..100
int dir = 0;        // 1=Fwd, -1=Bwd, 0=Stop (UI-side expected)
String logLine = "";

// ---------------- Layout (clean) ----------------
final int PAD = 16;

int PORT_X, PORT_Y, PORT_W, PORT_H;
int BTN_REFRESH_X, BTN_REFRESH_Y, BTN_REFRESH_W, BTN_REFRESH_H;
int BTN_CONN_X, BTN_CONN_Y, BTN_CONN_W, BTN_CONN_H;

int BTN_ROW_Y, BTN_W, BTN_H;
int BTN_F_X, BTN_B_X, BTN_S_X;

int SL_X, SL_Y, SL_W, SL_H;
boolean dragging = false;

int PANEL_X, PANEL_Y, PANEL_W, PANEL_H;

void setup() {
  size(720, 420);
  textSize(14);
  refreshPorts();
  logLine = "Ready.";
  computeLayout();
}

void draw() {
  background(255);
  computeLayout();

  drawHeader();
  drawButtonsRow();
  drawSlider();
  drawStatusPanel();

  fill(80);
  text("Log: " + logLine, PAD, height - 14);
}

// ---------------- Layout ----------------
void computeLayout() {
  // Header row
  PORT_X = PAD;
  PORT_Y = PAD;
  PORT_W = width - PAD*2 - 140 - 10 - 160; // leave room for Refresh + Connect
  PORT_H = 30;

  BTN_REFRESH_W = 140;
  BTN_REFRESH_H = 30;
  BTN_REFRESH_X = PORT_X + PORT_W + 10;
  BTN_REFRESH_Y = PORT_Y;

  BTN_CONN_W = 160;
  BTN_CONN_H = 30;
  BTN_CONN_X = BTN_REFRESH_X + BTN_REFRESH_W + 10;
  BTN_CONN_Y = PORT_Y;

  // Button row
  BTN_ROW_Y = PORT_Y + PORT_H + 28;
  BTN_H = 46;
  int gap = 14;
  BTN_W = (width - PAD*2 - gap*2) / 3;

  BTN_F_X = PAD;
  BTN_B_X = PAD + BTN_W + gap;
  BTN_S_X = PAD + (BTN_W + gap) * 2;

  // Slider
  SL_X = PAD;
  SL_Y = BTN_ROW_Y + BTN_H + 40;
  SL_W = width - PAD*2;
  SL_H = 16;

  // Panel
  PANEL_X = PAD;
  PANEL_Y = SL_Y + 60;
  PANEL_W = width - PAD*2;
  PANEL_H = 120;
}

// ---------------- Draw: Header ----------------
void drawHeader() {
  fill(0);
  text("Motor Control  (mbed: F <0..100>, B <0..100>, S)", PAD, PAD - 2);

  // Port selector box
  stroke(60);
  fill(245);
  rect(PORT_X, PORT_Y, PORT_W, PORT_H, 8);

  fill(0);
  String p = getSelectedPortName();
  if (p == null) p = "(no ports)";
  text("Port: " + p + "  (click to cycle)", PORT_X + 12, PORT_Y + 20);

  // Refresh
  drawBtn(BTN_REFRESH_X, BTN_REFRESH_Y, BTN_REFRESH_W, BTN_REFRESH_H,
          "Refresh", color(240));

  // Connect
  drawBtn(BTN_CONN_X, BTN_CONN_Y, BTN_CONN_W, BTN_CONN_H,
          connected ? "Disconnect" : "Connect",
          connected ? color(255, 220, 220) : color(200, 200, 255));
}

// ---------------- Draw: Buttons row ----------------
void drawButtonsRow() {
  drawBtn(BTN_F_X, BTN_ROW_Y, BTN_W, BTN_H, "Forward (F)", color(210, 255, 210));
  drawBtn(BTN_B_X, BTN_ROW_Y, BTN_W, BTN_H, "Backward (B)", color(210, 255, 210));
  drawBtn(BTN_S_X, BTN_ROW_Y, BTN_W, BTN_H, "Stop (S)", color(255, 235, 180));
}

// ---------------- Draw: Slider ----------------
void drawSlider() {
  fill(0);
  text("Duty (%): " + dutyPct, SL_X, SL_Y - 10);

  stroke(60);
  fill(255);
  rect(SL_X, SL_Y, SL_W, SL_H, 8);

  float kx = map(dutyPct, 0, 100, SL_X, SL_X + SL_W);
  noStroke();
  fill(60, 140, 255);
  rect(kx - 7, SL_Y - 10, 14, SL_H + 20, 8);

  fill(120);
  text("Drag sets duty. On mouse release, sends F/B <duty> if motor is running.", SL_X, SL_Y + 40);
}

// ---------------- Draw: Status panel ----------------
void drawStatusPanel() {
  stroke(200);
  fill(250);
  rect(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 12);

  fill(0);
  text("Expected IO State (UI-side)", PANEL_X + 14, PANEL_Y + 26);

  int p13 = (dir == 1) ? 1 : 0;
  int p14 = (dir == -1) ? 1 : 0;
  String d = (dir == 1) ? "FORWARD" : (dir == -1) ? "BACKWARD" : "STOP";

  fill(30);
  text("DIR = " + d, PANEL_X + 14, PANEL_Y + 52);
  text("p13(motor_f) = " + p13, PANEL_X + 14, PANEL_Y + 78);
  text("p14(motor_r) = " + p14, PANEL_X + 210, PANEL_Y + 78);
  text("p18(motor_v duty) = " + dutyPct + "%", PANEL_X + 410, PANEL_Y + 78);

  fill(120);
  text("Note: shown state is what UI sent; mbed does not send real IO feedback.", PANEL_X + 14, PANEL_Y + 104);
}

// ---------------- Mouse ----------------
void mousePressed() {
  // Click port box cycles
  if (inside(mouseX, mouseY, PORT_X, PORT_Y, PORT_W, PORT_H)) {
    if (ports.length > 0) portIndex = (portIndex + 1) % ports.length;
    return;
  }

  // Refresh
  if (inside(mouseX, mouseY, BTN_REFRESH_X, BTN_REFRESH_Y, BTN_REFRESH_W, BTN_REFRESH_H)) {
    refreshPorts();
    logLine = "Ports refreshed.";
    return;
  }

  // Connect/Disconnect
  if (inside(mouseX, mouseY, BTN_CONN_X, BTN_CONN_Y, BTN_CONN_W, BTN_CONN_H)) {
    if (connected) disconnectPort();
    else connectPort();
    return;
  }

  // Forward
  if (inside(mouseX, mouseY, BTN_F_X, BTN_ROW_Y, BTN_W, BTN_H)) {
    dir = 1;
    sendCmd("F " + dutyPct);
    return;
  }

  // Backward
  if (inside(mouseX, mouseY, BTN_B_X, BTN_ROW_Y, BTN_W, BTN_H)) {
    dir = -1;
    sendCmd("B " + dutyPct);
    return;
  }

  // Stop
  if (inside(mouseX, mouseY, BTN_S_X, BTN_ROW_Y, BTN_W, BTN_H)) {
    dir = 0;
    sendCmd("S");
    return;
  }

  // Slider drag start
  if (inside(mouseX, mouseY, SL_X, SL_Y - 12, SL_W, SL_H + 24)) {
    dragging = true;
    updateDutyFromMouse(mouseX);
  }
}

void mouseDragged() {
  if (dragging) {
    updateDutyFromMouse(mouseX);
    // 拖动中不发送
  }
}

void mouseReleased() {
  if (dragging) {
    dragging = false;
    // 拖动结束后发送：只有 dir != 0 才发
    sendDutyIfRunning();
  }
}

void updateDutyFromMouse(int mx) {
  float r = constrain((mx - SL_X) / float(SL_W), 0, 1);
  dutyPct = round(r * 100.0);
}

// ---------------- Send duty after drag ----------------
void sendDutyIfRunning() {
  if (dir == 0) {
    logLine = "(duty set) motor STOP, not sending.";
    return;
  }
  if (!connected || port == null) {
    logLine = "(duty set) not connected, not sending.";
    return;
  }

  String cmd = (dir == 1) ? ("F " + dutyPct) : ("B " + dutyPct);
  port.write(cmd + "\n");
  logLine = ">> " + cmd;
}

// ---------------- Serial helpers ----------------
void refreshPorts() {
  ports = Serial.list();
  if (ports == null) ports = new String[0];
  if (ports.length == 0) portIndex = 0;
  else portIndex = constrain(portIndex, 0, ports.length - 1);
  println("Ports:");
  printArray(ports);
}

String getSelectedPortName() {
  if (ports == null || ports.length == 0) return null;
  if (portIndex < 0 || portIndex >= ports.length) return null;
  return ports[portIndex];
}

void connectPort() {
  disconnectPort();
  String p = getSelectedPortName();
  if (p == null) {
    logLine = "No serial ports.";
    return;
  }
  try {
    port = new Serial(this, p, BAUD);
    port.clear();
    delay(80);
    while (port.available() > 0) port.read();
    connected = true;
    logLine = "Connected: " + p;
  } catch (Exception e) {
    logLine = "Failed to open: " + p;
    connected = false;
    port = null;
  }
}

void disconnectPort() {
  if (port != null) {
    try { port.stop(); } catch (Exception ignored) {}
    port = null;
  }
  connected = false;
  logLine = "Disconnected.";
}

void sendCmd(String s) {
  if (!connected || port == null) {
    logLine = "Not connected. Ignored: " + s;
    return;
  }
  port.write(s + "\n");
  logLine = ">> " + s;
}

// ---------------- UI helpers ----------------
void drawBtn(int x, int y, int w, int h, String label, int bg) {
  stroke(60);
  fill(bg);
  rect(x, y, w, h, 10);
  fill(0);
  float tx = x + (w - textWidth(label)) / 2.0;
  float ty = y + (h/2) + 5;
  text(label, tx, ty);
}

boolean inside(int mx, int my, int x, int y, int w, int h) {
  return (mx >= x && mx <= x+w && my >= y && my <= y+h);
}

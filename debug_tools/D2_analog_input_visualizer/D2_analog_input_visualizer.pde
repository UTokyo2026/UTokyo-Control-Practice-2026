import processing.serial.*;

// ================= Serial =================
final int BAUD = 115200;
Serial port;
String[] ports = new String[0];
int portIndex = 0;
boolean connected = false;

// ================= UI =================
final int PAD = 16;
String logLine = "Ready.";

// ================= Data =================
// latest values 0..255 (raw from serial)
int ch1=0, ch2=0, ch3=0, ch4=0;
int frames = 0;
int badBytes = 0;

// frame parser state
// 0=wait AA, 1=wait 55, 2=read ch1..ch4
int state = 0;
int byteIndex = 0;
int[] tmp = new int[4];

// ================= Layout =================
int PORT_X, PORT_Y, PORT_W, PORT_H;
int BTN_REFRESH_X, BTN_REFRESH_Y, BTN_REFRESH_W, BTN_REFRESH_H;
int BTN_CONN_X, BTN_CONN_Y, BTN_CONN_W, BTN_CONN_H;

void setup() {
  size(820, 460);
  textSize(14);
  refreshPorts();
  computeLayout();
}

void draw() {
  background(255);
  computeLayout();

  drawHeader();
  drawValuesPanel();
  drawBars();
  drawFooter();

  readSerialFrames();
}

// ================= Layout =================
void computeLayout() {
  PORT_X = PAD;
  PORT_Y = PAD;
  PORT_W = width - PAD*2 - 140 - 10 - 160;
  PORT_H = 30;

  BTN_REFRESH_W = 140;
  BTN_REFRESH_H = 30;
  BTN_REFRESH_X = PORT_X + PORT_W + 10;
  BTN_REFRESH_Y = PORT_Y;

  BTN_CONN_W = 160;
  BTN_CONN_H = 30;
  BTN_CONN_X = BTN_REFRESH_X + BTN_REFRESH_W + 10;
  BTN_CONN_Y = PORT_Y;
}

// ================= Draw =================
void drawHeader() {
  fill(0);
  text("4ch Analog Debug (Frame: AA 55 CH1 CH2 CH3 CH4)", PAD, PAD - 2);

  // Port selector box
  stroke(60);
  fill(245);
  rect(PORT_X, PORT_Y, PORT_W, PORT_H, 8);

  fill(0);
  String p = getSelectedPortName();
  if (p == null) p = "(no ports)";
  text("Port: " + p + "  (click to cycle)", PORT_X + 12, PORT_Y + 20);

  // Buttons
  drawBtn(BTN_REFRESH_X, BTN_REFRESH_Y, BTN_REFRESH_W, BTN_REFRESH_H,
          "Refresh", color(240));

  drawBtn(BTN_CONN_X, BTN_CONN_Y, BTN_CONN_W, BTN_CONN_H,
          connected ? "Disconnect" : "Connect",
          connected ? color(255, 220, 220) : color(200, 200, 255));
}

void drawValuesPanel() {
  int x = PAD, y = 70, w = width - PAD*2, h = 132;

  stroke(200);
  fill(250);
  rect(x, y, w, h, 12);

  fill(0);
  // ======= Updated labels per request: CH1=p16, CH2=p17, CH3=p19, CH4=p20
  text("Decoded Channels (raw 0..255)  [CH1=p16, CH2=p17, CH3=p19, CH4=p20]", x + 14, y + 26);

  fill(30);
  text("CH1 (p16): " + ch1, x + 14,  y + 55);
  text("CH2 (p17): " + ch2, x + 230, y + 55);
  text("CH3 (p19): " + ch3, x + 440, y + 55);
  text("CH4 (p20): " + ch4, x + 630, y + 55);

  // also show normalized 0..1
  text("CH1: " + nf(ch1/255.0,1,3), x + 14,  y + 82);
  text("CH2: " + nf(ch2/255.0,1,3), x + 230, y + 82);
  text("CH3: " + nf(ch3/255.0,1,3), x + 440, y + 82);
  text("CH4: " + nf(ch4/255.0,1,3), x + 630, y + 82);

  fill(120);
  text("Frames: " + frames + "   Bad bytes: " + badBytes + "   (auto re-sync by header)",
       x + 14, y + 110);
}

void drawBars() {
  int x = PAD, y = 220, w = width - PAD*2, h = 195;

  stroke(200);
  fill(252);
  rect(x, y, w, h, 12);

  fill(0);
  text("Simple Bar View (0..1)", x + 14, y + 26);

  int barX = x + 160;               // 给标签留更多空间
  int barW = w - 210;               // 右侧也留点空
  int barH = 22;
  int gap = 16;

  // Bars still fill based on raw value, but the numeric display at right is 0..1 now.
  drawOneBar("CH1 p16", ch1, barX, y + 50,                 barW, barH);
  drawOneBar("CH2 p17", ch2, barX, y + 50 + (barH+gap)*1,  barW, barH);
  drawOneBar("CH3 p19", ch3, barX, y + 50 + (barH+gap)*2,  barW, barH);
  drawOneBar("CH4 p20", ch4, barX, y + 50 + (barH+gap)*3,  barW, barH);

  // Tip：往上挪一点，避免贴到底部被遮挡/拥挤
  fill(120);
  text("Tip: if values look frozen -> check baud / wiring / device is sending frames.",
       x + 14, y + h + 15);
}

void drawOneBar(String name, int v, int x, int y, int w, int h) {
  fill(40);
  text(name, x - 145, y + 16);   // 标签更靠左，避免挤到条形图

  stroke(80);
  fill(255);
  rect(x, y, w, h, 8);

  float r = constrain(v / 255.0, 0, 1);
  noStroke();
  fill(60, 140, 255);
  rect(x, y, w*r, h, 8);

  // Right-side numeric as 0..1
  fill(0);
  text(nf(r, 1, 3), x + w + 10, y + 16);
}

void drawFooter() {
  fill(80);
  text("Log: " + logLine, PAD, height - 14);
}

// ================= Mouse =================
void mousePressed() {
  // port box cycles
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
}

// ================= Serial Frame Parser =================
void readSerialFrames() {
  if (!connected || port == null) return;

  while (port.available() > 0) {
    int b = port.read();      // 0..255
    b &= 0xFF;

    switch (state) {
      case 0: // wait AA
        if (b == 0xAA) state = 1;
        else badBytes++;
        break;

      case 1: // wait 55
        if (b == 0x55) {
          state = 2;
          byteIndex = 0;
        } else {
          state = (b == 0xAA) ? 1 : 0;
          badBytes++;
        }
        break;

      case 2: // read 4 bytes
        tmp[byteIndex++] = b;
        if (byteIndex >= 4) {
          ch1 = tmp[0];
          ch2 = tmp[1];
          ch3 = tmp[2];
          ch4 = tmp[3];
          frames++;
          state = 0; // next frame
        }
        break;
    }
  }
}

// ================= Serial helpers =================
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

    // reset parser
    state = 0;
    byteIndex = 0;
    frames = 0;
    badBytes = 0;

    connected = true;
    logLine = "Connected: " + p + " @ " + BAUD;
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

// ================= UI helpers =================
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

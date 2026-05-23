/*
 * ESP8266 + GDY-31 蓝牙 + WiFi 双模版
 * 支持蓝牙和WiFi同时发送数据到Flutter应用
 */

#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

// ============================================
// WiFi配置
// ============================================
const char* WIFI_SSID = "zlt";
const char* WIFI_PASSWORD = "12345678";

// ============================================
// 网络配置
// ============================================
const uint16_t DISCOVERY_PORT = 4210;
const uint16_t DATA_PORT = 8080;
const char* DEVICE_NAME = "ESP8266 BT/WiFi Sensor";
const char* DEVICE_ID = "esp8266_bt_001";

WiFiUDP udp;
WiFiServer server(DATA_PORT);

// ============================================
// 发送间隔
// ============================================
const unsigned long DATA_INTERVAL = 2000;
unsigned long lastSendTime = 0;
unsigned long bootTime;
int connectionCount = 0;
int packetsSent = 0;

// ============================================
// 模拟温湿度
// ============================================
float temperature = 20.0;
float humidity = 50.0;
bool tempUp = true;
bool humiUp = false;

void setup() {
  Serial.begin(9600);
  bootTime = millis();
  
  delay(100);
  Serial.println("========================================");
  Serial.println("ESP8266 蓝牙+WiFi 双模传感器");
  Serial.println("========================================");
  Serial.println();
  
  // 连接WiFi
  Serial.print("正在连接 WiFi: ");
  Serial.println(WIFI_SSID);
  
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n\n✓ WiFi连接成功！");
    Serial.print("  IP地址: ");
    Serial.println(WiFi.localIP());
    Serial.print("  信号强度: ");
    Serial.print(WiFi.RSSI());
    Serial.println(" dBm");
  } else {
    Serial.println("\n\n✗ WiFi连接失败！");
    Serial.println("  将仅通过蓝牙模式工作");
  }
  
  // 初始化网络服务
  udp.begin(DISCOVERY_PORT);
  server.begin();
  
  Serial.println();
  Serial.println("========================================");
  Serial.print("UDP发现端口: ");
  Serial.println(DISCOVERY_PORT);
  Serial.print("TCP数据端口: ");
  Serial.println(DATA_PORT);
  Serial.println("========================================");
  Serial.println();
  Serial.println("开始发送数据...");
  Serial.println("可通过WiFi或蓝牙接收数据");
  Serial.println();
  
  delay(500);
}

void loop() {
  unsigned long currentTime = millis();
  
  // 处理WiFi发现请求
  handleDiscovery();
  
  // 处理WiFi TCP客户端
  handleWiFiClient();
  
  // 定期发送数据
  if (currentTime - lastSendTime >= DATA_INTERVAL) {
    lastSendTime = currentTime;
    
    updateSensorData();
    sendSensorData();
    
    // 同时通过蓝牙发送（如果需要）
    // sendBluetoothData();  // 如果GDY-31连接的话
  }
  
  delay(10);
}

void handleDiscovery() {
  int packetSize = udp.parsePacket();
  if (packetSize <= 0) return;
  
  char buffer[128];
  int len = udp.read(buffer, sizeof(buffer) - 1);
  if (len <= 0) return;
  buffer[len] = '\0';
  
  String request = String(buffer);
  request.trim();
  
  if (request == "DATA_MONITOR_DISCOVER") {
    Serial.println("\n收到WiFi发现请求");
    
    String reply = "{";
    reply += "\"type\":\"data_monitor_device\",";
    reply += "\"name\":\"" + String(DEVICE_NAME) + "\",";
    reply += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
    reply += "\"host\":\"" + WiFi.localIP().toString() + "\",";
    reply += "\"port\":" + String(DATA_PORT);
    reply += "}";
    
    udp.beginPacket(udp.remoteIP(), udp.remotePort());
    udp.write(reply.c_str());
    udp.endPacket();
    
    Serial.println("已发送发现响应");
  }
}

void handleWiFiClient() {
  WiFiClient client = server.available();
  if (!client) return;
  
  Serial.println("\n========================================");
  Serial.println("WiFi客户端已连接！");
  Serial.println("========================================");
  connectionCount++;
  Serial.print("连接次数: #");
  Serial.println(connectionCount);
  Serial.print("客户端IP: ");
  Serial.println(client.remoteIP().toString());
  
  while (client.connected()) {
    // 处理心跳
    if (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      
      if (line == "ping") {
        Serial.println("收到心跳包 (ping)");
      }
    }
    
    // 数据通过handleClient在loop中发送
    delay(10);
  }
  
  Serial.println("WiFi客户端已断开");
}

void sendSensorData() {
  unsigned long timestamp = millis();
  
  String data = "{";
  data += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  data += "\"timestamp\":" + String(timestamp) + ",";
  data += "\"data\":{";
  data += "\"temperature\":" + String(temperature, 1);
  data += ",\"humidity\":" + String(humidity, 1);
  data += "}}";
  
  // 发送到WiFi TCP客户端
  WiFiClient client = server.available();
  if (client) {
    client.println(data);
  }
  
  // 同时通过串口（蓝牙）发送
  Serial.println(data);
  
  packetsSent++;
  Serial.print("已发送数据包 #");
  Serial.println(packetsSent);
}

void updateSensorData() {
  if (tempUp) {
    temperature += random(0, 3) * 0.1;
    if (temperature >= 30) tempUp = false;
  } else {
    temperature -= random(0, 3) * 0.1;
    if (temperature <= 18) tempUp = true;
  }

  if (humiUp) {
    humidity += random(0, 4) * 0.1;
    if (humidity >= 70) humiUp = false;
  } else {
    humidity -= random(0, 4) * 0.1;
    if (humidity <= 35) humiUp = true;
  }

  temperature = constrain(temperature, 15.0, 35.0);
  humidity = constrain(humidity, 30.0, 80.0);
}

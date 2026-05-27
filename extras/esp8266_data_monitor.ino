/*
  ESP8266 数据监控助手 - 模拟传感器数据发送程序
  
  功能：
  1. WiFi 连接到指定网络
  2. 支持 UDP 设备发现协议（DATA_MONITOR_DISCOVER）
  3. TCP 服务器发送模拟传感器数据
  4. 生成模拟温度、湿度、电压、电流数据
  
  配合数据监控助手使用：https://github.com/AloneGPU/date-analysis
  
  硬件：ESP8266 (NodeMCU, Wemos D1 mini 等)
*/

#include <ESP8266WiFi.h>
#include <WiFiUdp.h>

// WiFi 配置 - 修改为你的网络信息
const char* ssid = "zlt";
const char* password = "12345678";

// 设备配置
const char* deviceName = "ESP8266 Sensor";
const char* deviceId = "esp8266_001";
const uint16_t discoveryPort = 4210;  // UDP 发现端口
const uint16_t dataPort = 8080;       // TCP 数据端口

// WiFi 对象
WiFiUDP udp;
WiFiServer server(dataPort);
WiFiClient client;

// 模拟数据变量
float temperature = 25.0;
float humidity = 60.0;
float voltage = 3.3;
float current = 0.5;

// 数据发送间隔（毫秒）
const unsigned long sendInterval = 1000;
unsigned long lastSendTime = 0;

void setup() {
  // 初始化串口
  Serial.begin(115200);
  Serial.println();
  Serial.println("========================================");
  Serial.println("  ESP8266 数据监控助手 v1.0");
  Serial.println("========================================");

  // 连接 WiFi
  connectWiFi();

  // 启动 UDP 监听（设备发现）
  if (udp.begin(discoveryPort)) {
    Serial.printf("UDP 发现服务启动: %d\n", discoveryPort);
  }

  // 启动 TCP 服务器
  server.begin();
  server.setNoDelay(true);
  Serial.printf("TCP 数据服务启动: %d\n", dataPort);
  
  Serial.println("========================================");
}

void connectWiFi() {
  Serial.printf("连接 WiFi: %s\n", ssid);
  
  WiFi.mode(WIFI_STA);
  WiFi.begin(ssid, password);

  // 等待连接
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("IP 地址: ");
    Serial.println(WiFi.localIP());
    Serial.print("MAC 地址: ");
    Serial.println(WiFi.macAddress());
  } else {
    Serial.println();
    Serial.println("WiFi 连接失败！");
  }
}

void handleDiscovery() {
  // 检查是否有 UDP 数据包
  int packetSize = udp.parsePacket();
  if (packetSize <= 0) return;

  // 读取数据包
  char buffer[128];
  int len = udp.read(buffer, sizeof(buffer) - 1);
  if (len <= 0) return;
  buffer[len] = '\0';

  // 解析请求
  String request = String(buffer);
  request.trim();
  
  // 检查是否为发现请求
  if (request == "DATA_MONITOR_DISCOVER") {
    Serial.printf("收到发现请求: %s:%d\n", udp.remoteIP().toString().c_str(), udp.remotePort());
    
    // 构建响应 JSON
    String reply = "{";
    reply += "\"type\":\"data_monitor_device\",";
    reply += "\"name\":\"" + String(deviceName) + "\",";
    reply += "\"deviceId\":\"" + String(deviceId) + "\",";
    reply += "\"host\":\"" + WiFi.localIP().toString() + "\",";
    reply += "\"port\":" + String(dataPort);
    reply += "}";

    // 发送响应
    udp.beginPacket(udp.remoteIP(), udp.remotePort());
    udp.write((const uint8_t*)reply.c_str(), reply.length());
    udp.endPacket();
    
    Serial.printf("已响应发现请求\n");
  }
}

void generateMockData() {
  // 模拟温度变化（20-35°C）
  temperature += (random(-10, 11) * 0.1);
  temperature = constrain(temperature, 20.0, 35.0);

  // 模拟湿度变化（40-80%）
  humidity += (random(-5, 6) * 0.5);
  humidity = constrain(humidity, 40.0, 80.0);

  // 模拟电压变化（3.0-3.5V）
  voltage += (random(-2, 3) * 0.02);
  voltage = constrain(voltage, 3.0, 3.5);

  // 模拟电流变化（0.3-0.8A）
  current += (random(-5, 6) * 0.02);
  current = constrain(current, 0.3, 0.8);
}

void sendData() {
  if (!client.connected()) return;

  // 生成模拟数据
  generateMockData();

  // 构建 JSON 数据
  String data = "{";
  data += "\"device_id\":\"" + String(deviceId) + "\",";
  data += "\"timestamp\":" + String(millis()) + ",";
  data += "\"data\":{";
  data += "\"temperature\":" + String(temperature, 2) + ",";
  data += "\"humidity\":" + String(humidity, 1) + ",";
  data += "\"voltage\":" + String(voltage, 2) + ",";
  data += "\"current\":" + String(current, 2);
  data += "}";
  data += "}";

  // 发送数据
  client.println(data);
  
  // 打印到串口
  Serial.println(data);
}

void handleClient() {
  // 检查是否有新客户端连接
  if (!client.connected()) {
    client = server.available();
    if (client) {
      Serial.printf("客户端已连接: %s:%d\n", client.remoteIP().toString().c_str(), client.remotePort());
    }
    return;
  }

  // 检查客户端是否断开
  if (!client.connected()) {
    Serial.println("客户端已断开");
    client.stop();
    return;
  }

  // 检查是否有客户端数据（心跳等）
  if (client.available()) {
    String line = client.readStringUntil('\n');
    line.trim();
    if (line == "ping") {
      Serial.println("收到心跳请求");
      // 可选：回复心跳
      // client.println("pong");
    }
  }

  // 定时发送数据
  unsigned long now = millis();
  if (now - lastSendTime >= sendInterval) {
    sendData();
    lastSendTime = now;
  }
}

void loop() {
  // 处理 WiFi 重连
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi 断开，尝试重连...");
    connectWiFi();
    delay(1000);
    return;
  }

  // 处理设备发现
  handleDiscovery();

  // 处理客户端连接和数据发送
  handleClient();
}

/*
  使用说明：
  
  1. 安装 ESP8266 Arduino 开发环境
     - 在 Arduino IDE 中添加额外开发板管理器地址：
       http://arduino.esp8266.com/stable/package_esp8266com_index.json
     - 安装 ESP8266 开发板
  
  2. 修改配置：
     - ssid: 你的 WiFi 名称
     - password: 你的 WiFi 密码
  
  3. 上传到 ESP8266
  
  4. 使用数据监控助手：
     - 选择 WiFi 通讯方式
     - 点击"扫描局域网设备"
     - 选择发现的 ESP8266 设备
     - 点击连接开始接收数据
  
  5. 手动连接（如果发现失败）：
     - 在串口监视器查看 ESP8266 的 IP 地址
     - 在数据监控助手中手动输入 IP 和端口 8080
  
  技术参数：
  - UDP 发现端口：4210
  - TCP 数据端口：8080
  - 数据格式：JSON + 换行符
  - 发送频率：每秒一次
*/
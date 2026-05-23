/*
 * ESP8266 + INMP441 分贝检测工具 - 简化版
 * 注意：ESP8266的I2S支持有限，这个版本使用更兼容的方案
 * 或者可以使用 MAX4466 + 模拟输入 作为替代方案
 */

#include <ESP8266WiFi.h>
#include <WiFiUdp.h>
#include <Wire.h>

// ============================================
// WiFi配置
// ============================================
#include "wifi_config.h"

// ============================================
// 网络配置
// ============================================
const uint16_t DISCOVERY_PORT = 4210;
const uint16_t DATA_PORT = 8080;
const char* DEVICE_NAME = "ESP8266 Decibel Sensor";
const char* DEVICE_ID = "esp8266_db_001";

WiFiUDP udp;
WiFiServer server(DATA_PORT);

// ============================================
// 分贝检测配置（模拟版本）
// ============================================
// 由于ESP8266 I2S支持问题，这个版本：
// 1. 可以使用模拟麦克风（如MAX4466）连接到A0
// 2. 或者先模拟数据进行测试

#define MIC_PIN A0  // 模拟输入引脚

const unsigned long MEASUREMENT_INTERVAL = 500;  // 测量间隔（毫秒）
const unsigned long DATA_SEND_INTERVAL = 1000;   // 数据发送间隔

float currentDecibel = 0.0;
float maxDecibel = 0.0;
float minDecibel = 999.0;
float avgDecibel = 0.0;
int sampleCount = 0;
unsigned long lastMeasurementTime = 0;
unsigned long lastSendTime = 0;

// 模拟数据模式（用于测试，不依赖硬件）
bool useSimulatedData = true;
float simulatedDecibel = 50.0;
bool simUp = true;

// ============================================
// 初始化函数
// ============================================
void setup() {
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("ESP8266 分贝检测工具");
  Serial.println("========================================\n");
  
  if (useSimulatedData) {
    Serial.println("⚠️  当前模式：模拟数据（用于测试）");
    Serial.println("   要使用真实麦克风，请设置 useSimulatedData = false\n");
  } else {
    Serial.println("✅  当前模式：真实麦克风");
    Serial.println("   请将麦克风模块连接到A0引脚\n");
  }
  
  // 连接WiFi
  Serial.print("连接到 WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 30) {
    delay(500);
    Serial.print(".");
    attempts++;
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi连接成功！");
    Serial.print("IP地址: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi连接失败，将在本地工作模式\n");
  }
  
  // 初始化UDP发现和TCP服务器
  udp.begin(DISCOVERY_PORT);
  server.begin();
  
  Serial.print("发现端口 (UDP): ");
  Serial.println(DISCOVERY_PORT);
  Serial.print("数据端口 (TCP): ");
  Serial.println(DATA_PORT);
  Serial.println("\n系统准备就绪！");
  Serial.println("========================================\n");
}

// ============================================
// 主循环
// ============================================
void loop() {
  unsigned long currentTime = millis();
  
  // 处理发现请求
  handleDiscovery();
  
  // 处理TCP客户端连接
  handleClient();
  
  // 定期测量分贝
  if (currentTime - lastMeasurementTime >= MEASUREMENT_INTERVAL) {
    lastMeasurementTime = currentTime;
    measureDecibel();
  }
  
  // 定期发送数据
  if (currentTime - lastSendTime >= DATA_SEND_INTERVAL) {
    lastSendTime = currentTime;
    printDecibelData();
  }
  
  delay(10);
}

// ============================================
// 测量分贝函数
// ============================================
void measureDecibel() {
  if (useSimulatedData) {
    // 模拟数据模式 - 用于测试
    simulateDecibelData();
  } else {
    // 真实数据模式 - 从A0读取
    readAnalogDecibel();
  }
  
  // 更新统计数据
  sampleCount++;
  avgDecibel = (avgDecibel * (sampleCount - 1) + currentDecibel) / sampleCount;
  
  if (currentDecibel > maxDecibel) maxDecibel = currentDecibel;
  if (currentDecibel < minDecibel) minDecibel = currentDecibel;
}

// ============================================
// 模拟分贝数据
// ============================================
void simulateDecibelData() {
  // 生成自然变化的分贝值
  if (simUp) {
    simulatedDecibel += random(0, 5) * 0.5;
    if (simulatedDecibel >= 80) simUp = false;
  } else {
    simulatedDecibel -= random(0, 5) * 0.5;
    if (simulatedDecibel <= 30) simUp = true;
  }
  
  currentDecibel = simulatedDecibel;
  
  // 确保在合理范围内
  if (currentDecibel < 0) currentDecibel = 0;
  if (currentDecibel > 120) currentDecibel = 120;
}

// ============================================
// 从模拟引脚读取分贝值
// ============================================
void readAnalogDecibel() {
  const int NUM_SAMPLES = 256;
  long sum = 0;
  
  // 读取多个样本
  for (int i = 0; i < NUM_SAMPLES; i++) {
    int value = analogRead(MIC_PIN);
    sum += abs(value - 512); // 减去中心值（假设10位ADC，中心512）
  }
  
  // 计算平均值
  double avgValue = (double)sum / NUM_SAMPLES;
  
  // 转换为分贝值（需要校准）
  // 这是一个简化的转换公式，实际需要根据硬件校准
  currentDecibel = 20 * log10(avgValue + 1); // +1 避免log(0)
  
  // 校准偏移（根据实际硬件调整）
  currentDecibel += 30; // 偏移值，根据环境调整
  
  // 确保在合理范围内
  if (currentDecibel < 0) currentDecibel = 0;
  if (currentDecibel > 120) currentDecibel = 120;
}

// ============================================
// 打印分贝数据
// ============================================
void printDecibelData() {
  Serial.print("[分贝] 当前: ");
  Serial.print(currentDecibel, 1);
  Serial.print(" dB | 平均: ");
  Serial.print(avgDecibel, 1);
  Serial.print(" dB | 最大: ");
  Serial.print(maxDecibel, 1);
  Serial.print(" dB | 最小: ");
  Serial.print(minDecibel, 1);
  Serial.println(" dB");
}

// ============================================
// 处理发现请求
// ============================================
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
    Serial.println("收到发现请求");
    
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
    
    Serial.println("发送发现响应");
  }
}

// ============================================
// 处理TCP客户端
// ============================================
void handleClient() {
  WiFiClient client = server.available();
  if (!client) return;
  
  Serial.println("\n客户端已连接！");
  
  while (client.connected()) {
    unsigned long currentTime = millis();
    
    // 处理心跳
    if (client.available()) {
      String line = client.readStringUntil('\n');
      line.trim();
      if (line == "ping") {
        Serial.println("收到心跳");
      }
    }
    
    // 定期发送数据
    if (currentTime - lastSendTime >= DATA_SEND_INTERVAL) {
      lastSendTime = currentTime;
      sendDecibelData(client);
    }
    
    delay(10);
  }
  
  Serial.println("客户端已断开\n");
}

// ============================================
// 发送分贝数据
// ============================================
void sendDecibelData(WiFiClient &client) {
  unsigned long timestamp = millis();
  
  String data = "{";
  data += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  data += "\"timestamp\":" + String(timestamp) + ",";
  data += "\"data\":{";
  data += "\"decibel\":" + String(currentDecibel, 1);
  data += ",\"avg_decibel\":" + String(avgDecibel, 1);
  data += ",\"max_decibel\":" + String(maxDecibel, 1);
  data += ",\"min_decibel\":" + String(minDecibel, 1);
  data += "}}";
  
  client.println(data);
  
  Serial.print("发送数据: ");
  Serial.println(data);
}

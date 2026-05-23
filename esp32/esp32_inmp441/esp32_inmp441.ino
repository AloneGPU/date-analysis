/*
 * ESP32 + INMP441 高精度分贝检测工具
 * 作者：数据监控系统
 * 日期：2026-05-23
 * 
 * ESP32对I2S支持更好，推荐使用ESP32 + INMP441
 */

#include <WiFi.h>
#include <WiFiUdp.h>
#include <driver/i2s.h>

// ============================================
// WiFi配置
// ============================================
const char* WIFI_SSID = "你的WiFi名称";
const char* WIFI_PASSWORD = "你的WiFi密码";

// ============================================
// 网络配置
// ============================================
const uint16_t DISCOVERY_PORT = 4210;
const uint16_t DATA_PORT = 8080;
const char* DEVICE_NAME = "ESP32 Decibel Sensor";
const char* DEVICE_ID = "esp32_db_001";

WiFiUDP udp;
WiFiServer server(DATA_PORT);

// ============================================
// INMP441 I2S 配置
// ============================================
#define I2S_SD_PIN 32    // INMP441 SD (数据输出)
#define I2S_WS_PIN 25    // INMP441 WS (字选择)
#define I2S_SCK_PIN 26   // INMP441 SCK (时钟)

#define SAMPLE_RATE 16000    // 采样率 (16kHz)
#define SAMPLE_BITS 16       // 采样位宽
#define BUFFER_SIZE 512      // 缓冲区大小

// ============================================
// 分贝检测配置
// ============================================
const unsigned long MEASUREMENT_INTERVAL = 100;  // 快速测量
const unsigned long DATA_SEND_INTERVAL = 1000;  // 1秒发送一次

float currentDecibel = 0.0;
float maxDecibel = 0.0;
float minDecibel = 999.0;
float avgDecibel = 0.0;
int sampleCount = 0;
unsigned long lastMeasurementTime = 0;
unsigned long lastSendTime = 0;

// 校准值（根据你的环境调整）
float calibrationOffset = 0.0;

// ============================================
// 初始化函数
// ============================================
void setup() {
  Serial.begin(115200);
  delay(500);
  
  Serial.println("\n========================================");
  Serial.println("ESP32 + INMP441 高精度分贝检测工具");
  Serial.println("========================================\n");
  
  // 初始化I2S
  Serial.println("初始化I2S接口...");
  initI2S();
  Serial.println("I2S初始化成功\n");
  
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
  
  // 预热（读取一些样本稳定）
  Serial.println("传感器预热中...");
  for (int i = 0; i < 10; i++) {
    measureDecibel();
    delay(100);
  }
  Serial.println("预热完成！\n");
}

// ============================================
// I2S初始化函数（ESP32）
// ============================================
void initI2S() {
  i2s_config_t i2s_config = {
    .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_RX),
    .sample_rate = SAMPLE_RATE,
    .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
    .channel_format = I2S_CHANNEL_FMT_ONLY_LEFT,
    .communication_format = I2S_COMM_FORMAT_STAND_I2S,
    .intr_alloc_flags = ESP_INTR_FLAG_LEVEL1,
    .dma_buf_count = 8,
    .dma_buf_len = 64,
    .use_apll = false,
    .tx_desc_auto_clear = false,
    .fixed_mclk = 0
  };
  
  i2s_pin_config_t pin_config = {
    .bck_io_num = I2S_SCK_PIN,
    .ws_io_num = I2S_WS_PIN,
    .data_out_num = -1,
    .data_in_num = I2S_SD_PIN
  };
  
  i2s_driver_install(I2S_NUM_0, &i2s_config, 0, NULL);
  i2s_set_pin(I2S_NUM_0, &pin_config);
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
  // 读取音频样本
  size_t bytes_read;
  int16_t samples[BUFFER_SIZE];
  
  i2s_read(I2S_NUM_0, samples, BUFFER_SIZE * sizeof(int16_t), &bytes_read, 100);
  int sample_count = bytes_read / sizeof(int16_t);
  
  if (sample_count <= 0) return;
  
  // 计算均方根值 (RMS)
  double sum_squared = 0;
  for (int i = 0; i < sample_count; i++) {
    sum_squared += (double)samples[i] * samples[i];
  }
  
  double rms = sqrt(sum_squared / sample_count);
  
  // 转换为分贝值
  // INMP441的灵敏度为 -26 dBFS（满量程分贝）
  // 94 dB SPL参考
  const double reference = 32768.0; // 16位最大值
  const double spl_reference = 94.0;
  const double mic_sensitivity = -26.0;
  
  currentDecibel = 20 * log10(rms / reference) - mic_sensitivity + spl_reference;
  
  // 应用校准
  currentDecibel += calibrationOffset;
  
  // 确保值在合理范围内
  if (currentDecibel < 0) currentDecibel = 0;
  if (currentDecibel > 120) currentDecibel = 120;
  
  // 更新统计数据
  sampleCount++;
  avgDecibel = (avgDecibel * (sampleCount - 1) + currentDecibel) / sampleCount;
  
  if (currentDecibel > maxDecibel) maxDecibel = currentDecibel;
  if (currentDecibel < minDecibel) minDecibel = currentDecibel;
}

// ============================================
// 打印分贝数据
// ============================================
void printDecibelData() {
  String level = getDecibelLevel(currentDecibel);
  
  Serial.print("[分贝] 当前: ");
  Serial.print(currentDecibel, 1);
  Serial.print(" dB | ");
  Serial.print(level);
  Serial.print(" | 平均: ");
  Serial.print(avgDecibel, 1);
  Serial.print(" dB | 最大: ");
  Serial.print(maxDecibel, 1);
  Serial.print(" dB | 最小: ");
  Serial.print(minDecibel, 1);
  Serial.println(" dB");
}

// ============================================
// 获取分贝等级描述
// ============================================
String getDecibelLevel(float db) {
  if (db < 30) return "极静";
  else if (db < 50) return "安静";
  else if (db < 65) return "正常";
  else if (db < 80) return "较吵";
  else if (db < 100) return "很吵";
  else return "极吵";
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
  String level = getDecibelLevel(currentDecibel);
  
  String data = "{";
  data += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  data += "\"timestamp\":" + String(timestamp) + ",";
  data += "\"data\":{";
  data += "\"decibel\":" + String(currentDecibel, 1);
  data += ",\"avg_decibel\":" + String(avgDecibel, 1);
  data += ",\"max_decibel\":" + String(maxDecibel, 1);
  data += ",\"min_decibel\":" + String(minDecibel, 1);
  data += ",\"level\":\"" + level + "\"";
  data += "}}";
  
  client.println(data);
  
  Serial.print("发送数据: ");
  Serial.println(data);
}

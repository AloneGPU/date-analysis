// ESP8266 + GDY-31 蓝牙 - 增强版
// 带调试功能的版本

// 配置选项
#define USE_SOFTWARE_SERIAL false    // 是否使用软件串口（需要SoftwareSerial库）
#define DEBUG_OUTPUT false           // 是否输出调试信息

// 发送间隔
const unsigned long DATA_INTERVAL = 2000;
unsigned long lastSendTime = 0;

// 设备信息
const char* DEVICE_ID = "esp8266_bt_001";
const char* DEVICE_NAME = "ESP8266 BT Sensor";

// 模拟温湿度
float temperature = 20.0;
float humidity = 50.0;
bool tempUp = true;
bool humiUp = false;

unsigned long bootTime;

#if USE_SOFTWARE_SERIAL
#include <SoftwareSerial.h>
SoftwareSerial bluetoothSerial(D2, D3);  // RX, TX
#endif

void setup() {
  // 调试串口
  Serial.begin(115200);
  
  // 蓝牙串口
  #if USE_SOFTWARE_SERIAL
  bluetoothSerial.begin(9600);
  #else
  Serial.begin(9600);  // 使用硬件串口（注意：上传代码时需要断开蓝牙）
  #endif
  
  bootTime = millis();
  
  delay(100);
  
  #if DEBUG_OUTPUT
  Serial.println("\n==========================================");
  Serial.println("ESP8266 + GDY-31 蓝牙传感器");
  Serial.println("==========================================");
  Serial.println("设备ID: " + String(DEVICE_ID));
  Serial.println("数据间隔: " + String(DATA_INTERVAL) + " ms");
  Serial.println("开始发送数据...\n");
  #endif
  
  // 通过蓝牙发送启动信息
  #if USE_SOFTWARE_SERIAL
  bluetoothSerial.println("ESP8266 BT Sensor Ready");
  #else
  Serial.println("ESP8266 BT Sensor Ready");
  #endif
  
  delay(500);
}

void loop() {
  if (millis() - lastSendTime >= DATA_INTERVAL) {
    lastSendTime = millis();
    
    updateSensorData();
    sendSensorData();
    
    #if DEBUG_OUTPUT
    printDebugInfo();
    #endif
  }
}

// 发送数据
void sendSensorData() {
  unsigned long timestamp = millis();
  
  String jsonData = "{";
  jsonData += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  jsonData += "\"timestamp\":" + String(timestamp) + ",";
  jsonData += "\"data\":{";
  jsonData += "\"temperature\":" + String(temperature, 1);
  jsonData += ",\"humidity\":" + String(humidity, 1);
  jsonData += "}}";
  
  #if USE_SOFTWARE_SERIAL
  bluetoothSerial.println(jsonData);
  #else
  Serial.println(jsonData);
  #endif
}

// 模拟数据
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

// 调试输出
#if DEBUG_OUTPUT
void printDebugInfo() {
  Serial.print("[");
  Serial.print(millis() - bootTime);
  Serial.print(" ms] ");
  Serial.print("Temperature: ");
  Serial.print(temperature, 1);
  Serial.print("°C | Humidity: ");
  Serial.print(humidity, 1);
  Serial.println("%");
  
  // 显示JSON格式
  String jsonData = "{";
  jsonData += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  jsonData += "\"timestamp\":" + String(millis()) + ",";
  jsonData += "\"data\":{";
  jsonData += "\"temperature\":" + String(temperature, 1);
  jsonData += ",\"humidity\":" + String(humidity, 1);
  jsonData += "}}";
  
  Serial.print("JSON: ");
  Serial.println(jsonData);
}
#endif

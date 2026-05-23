// ESP8266 + GDY-31 蓝牙
// Flutter数据监控应用兼容版

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

void setup() {
  // GDY-31 默认波特率 9600
  Serial.begin(9600);
  bootTime = millis();
  
  delay(100);
  Serial.println("蓝牙开始发送数据...");
  Serial.println("等待Flutter应用连接...");
  delay(500);
}

void loop() {
  if (millis() - lastSendTime >= DATA_INTERVAL) {
    lastSendTime = millis();
    
    updateSensorData();
    
    // 发送 Flutter 应用兼容的 JSON 格式
    sendSensorData();
  }
}

// 发送数据
void sendSensorData() {
  unsigned long timestamp = millis();
  
  Serial.print("{\"device_id\":\"");
  Serial.print(DEVICE_ID);
  Serial.print("\",\"timestamp\":");
  Serial.print(timestamp);
  Serial.print(",\"data\":{\"temperature\":");
  Serial.print(temperature, 1);
  Serial.print(",\"humidity\":");
  Serial.print(humidity, 1);
  Serial.println("}}");
  
  // 调试输出（可选）
  // 可以通过另一个串口查看，这里注释掉以避免干扰蓝牙数据
  /*
  Serial.print("[Debug] T=");
  Serial.print(temperature, 1);
  Serial.print("°C, H=");
  Serial.print(humidity, 1);
  Serial.println("%");
  */
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

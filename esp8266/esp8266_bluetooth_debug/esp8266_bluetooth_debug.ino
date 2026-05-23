# ESP8266 + GDY-31 蓝牙连接问题排查指南

## 🔍 常见问题排查步骤

### 第一步：检查硬件连接

```
GDY-31        ESP8266
TX (发送)  →  RX (接收)
RX (接收)  ←  TX (发送)
VCC (电源)  →  3.3V
GND (地)   →  GND
```

⚠️ **重要**：接线必须交叉连接！

### 第二步：检查波特率

GDY-31 默认波特率：**9600**

确认ESP8266代码中的波特率设置：
```cpp
Serial.begin(9600);  // 必须是9600
```

### 第三步：使用Arduino IDE串口监视器测试

1. **断开ESP8266与GDY-31的连接**（上传代码时必须断开）
2. 将ESP8266通过USB连接到电脑
3. 打开Arduino IDE的串口监视器
4. 设置波特率为 **9600**
5. 观察是否有数据输出

**应该看到的输出示例**：
```
{"device_id":"esp8266_bt_001","timestamp":1000,"data":{"temperature":20.5,"humidity":50.3}}
{"device_id":"esp8266_bt_001","timestamp":3000,"data":{"temperature":20.6,"humidity":50.4}}
```

### 第四步：检查GDY-31模块状态

**GDY-31/HC-05/HC-06 指示灯状态**：
- **快闪**（每秒几次）：等待配对
- **慢闪**（每2秒1次）：已配对，正在通信
- **常亮**：连接成功

## 🛠️ 常见问题及解决方案

### ❌ 问题1：串口监视器看不到数据

**原因**：ESP8266与电脑的USB连接波特率可能是115200

**解决**：
```cpp
// 在setup()中使用
Serial.begin(115200);  // 用于调试
Serial.println("Debug: ESP8266 Started");

Serial.begin(9600);    // GDY-31 蓝牙波特率
```

### ❌ 问题2：GDY-31指示灯一直快闪

**原因**：没有设备连接

**解决**：
1. 在手机蓝牙设置中搜索并配对GDY-31
2. 配对密码通常是 `0000` 或 `1234`
3. 配对成功后指示灯变为慢闪

### ❌ 问题3：Flutter应用显示"连接成功"但收不到数据

**原因**：数据格式或波特率问题

**解决**：
1. 确认Flutter应用的蓝牙波特率设置（通常自动检测）
2. 检查JSON格式是否完全正确
3. 添加调试输出来验证数据发送

### ❌ 问题4：数据断断续续

**原因**：
- 信号干扰
- 供电不足
- 波特率轻微不匹配

**解决**：
1. 缩短GDY-31与手机的距离
2. 使用独立的3.3V电源供电
3. 尝试更低的波特率（如4800）

## 📝 测试代码（带详细调试）

创建一个专门用于调试的版本：
<minimax:tool_call>
<invoke name="Write">
<parameter name="content">// ESP8266 + GDY-31 蓝牙 - 完整调试版
// 使用两个串口：一个用于调试，一个用于蓝牙

#include <SoftwareSerial.h>

// 调试串口配置（连接到电脑）
#define DEBUG_BAUD 115200

// 蓝牙串口配置（连接到GDY-31）
#define BT_RX_PIN D2    // ESP8266接收GDY-31的TX
#define BT_TX_PIN D3    // ESP8266发送 GDY-31的RX
#define BT_BAUD 9600    // GDY-31默认波特率

// 创建软件串口
SoftwareSerial btSerial(BT_RX_PIN, BT_TX_PIN);

// 发送间隔
const unsigned long DATA_INTERVAL = 1000;  // 1秒测试用
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
int packetCount = 0;

void setup() {
  // 初始化调试串口（连接到电脑）
  Serial.begin(DEBUG_BAUD);
  delay(500);
  
  // 初始化蓝牙串口（连接到GDY-31）
  btSerial.begin(BT_BAUD);
  delay(500);
  
  bootTime = millis();
  
  // 调试信息
  Serial.println("\n========================================");
  Serial.println("ESP8266 + GDY-31 蓝牙调试版本");
  Serial.println("========================================");
  Serial.println("配置信息：");
  Serial.println("  调试波特率: " + String(DEBUG_BAUD));
  Serial.println("  蓝牙波特率: " + String(BT_BAUD));
  Serial.println("  蓝牙RX引脚: D" + String(BT_RX_PIN));
  Serial.println("  蓝牙TX引脚: D" + String(BT_TX_PIN));
  Serial.println("  设备ID: " + String(DEVICE_ID));
  Serial.println("  发送间隔: " + String(DATA_INTERVAL) + " ms");
  Serial.println("========================================\n");
  
  // 通知蓝牙模块已就绪
  btSerial.println("ESP8266 BT Ready");
  Serial.println("已向蓝牙模块发送启动信息\n");
  
  // 等待连接稳定
  delay(1000);
  
  Serial.println("开始发送数据...\n");
}

void loop() {
  // 检查是否收到来自蓝牙模块的数据
  if (btSerial.available()) {
    String received = btSerial.readStringUntil('\n');
    received.trim();
    if (received.length() > 0) {
      Serial.print("蓝牙收到: ");
      Serial.println(received);
    }
  }
  
  // 按设定间隔发送数据
  if (millis() - lastSendTime >= DATA_INTERVAL) {
    lastSendTime = millis();
    
    updateSensorData();
    sendSensorData();
  }
  
  delay(10);
}

void sendSensorData() {
  unsigned long timestamp = millis();
  packetCount++;
  
  // 构建JSON数据
  String jsonData = "{";
  jsonData += "\"device_id\":\"" + String(DEVICE_ID) + "\",";
  jsonData += "\"timestamp\":" + String(timestamp) + ",";
  jsonData += "\"data\":{";
  jsonData += "\"temperature\":" + String(temperature, 1);
  jsonData += ",\"humidity\":" + String(humidity, 1);
  jsonData += "}}";
  
  // 通过蓝牙发送
  btSerial.println(jsonData);
  
  // 通过串口显示（调试用）
  Serial.print("[数据包 #");
  Serial.print(packetCount);
  Serial.print("] 发送时间: ");
  Serial.print(millis() - bootTime);
  Serial.print(" ms | 温度: ");
  Serial.print(temperature, 1);
  Serial.print("°C | 湿度: ");
  Serial.print(humidity, 1);
  Serial.println("%");
  
  Serial.print("JSON数据: ");
  Serial.println(jsonData);
}

void updateSensorData() {
  // 温度变化
  if (tempUp) {
    temperature += random(0, 3) * 0.1;
    if (temperature >= 30) tempUp = false;
  } else {
    temperature -= random(0, 3) * 0.1;
    if (temperature <= 18) tempUp = true;
  }
  
  // 湿度变化
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

# ESP8266 + GDY-31 蓝牙传感器

## 📱 与你的Flutter数据监控应用完全兼容！

## 📋 硬件连接

**GDY-31 蓝牙模块 ↔ ESP8266

```
GDY-31    ESP8266
TX    ↔   RX
RX    ↔   TX
VCC   ↔   3.3V
GND   ↔   GND
```

⚠️ 注意：GDY-31 的TX接ESP8266的RX，GDY-31的RX接ESP8266的TX（交叉连接）

## 🚀 快速开始

1. **上传代码**
   - 打开 `esp8266_bluetooth.ino` 到ESP8266
   
2. **连接蓝牙模块**
   - 按照上面的接线图连接GDY-31
   
3. **在Flutter应用中连接**
   - 打开数据监控应用
   - 选择"蓝牙"通信模式
   - 点击"扫描设备"
   - 选择GDY-31蓝牙设备（通常叫 "HC-05"、"HC-06" 或 "JDY-31"）
   - 配对密码通常是 `0000` 或 `1234`
   - 开始接收数据！

## 📊 数据格式

### 发送的JSON格式（兼容Flutter应用）

```json
{
  "device_id": "esp8266_bt_001",
  "timestamp": 1234567,
  "data": {
    "temperature": 24.5,
    "humidity": 55.3
  }
}
```

这个格式与你的Flutter应用的 [SensorData.fromJson](file:///workspace/lib/models/sensor_data.dart#L12-L18) 完全匹配！

## 🔧 配置选项

### 修改设备信息
```cpp
const char* DEVICE_ID = "esp8266_bt_001";
const char* DEVICE_NAME = "ESP8266 BT Sensor";
```

### 修改发送间隔
```cpp
const unsigned long DATA_INTERVAL = 2000; // 2秒
```

### 修改数据范围
```cpp
// 在 updateSensorData() 函数中
if (temperature >= 30) tempUp = false;  // 最高温度
if (temperature <= 18) tempUp = true;   // 最低温度
if (humidity >= 70) humiUp = false;  // 最高湿度
if (humidity <= 35) humiUp = true;   // 最低湿度
```

## 💡 使用说明

### 常见GDY-31特点
- 工作电压：3.3V-6V
- 默认波特率：9600
- 工作模式：从机模式（Slave）
- 配对密码：0000 或 1234

### 在Flutter应用中使用

1. 打开你的数据监控应用
2. 进入连接页面
3. 选择"蓝牙"选项
4. 点击"扫描设备"
5. 从列表中选择GDY-31设备
6. 应用会自动解析数据并显示

### 故障排除

**问题：找不到设备**
- 检查GDY-31是否正确连接
- 确认供电是否正常（模块指示灯亮）
- 重新启动蓝牙
- 确认手机蓝牙已开启

**问题：连接不上**
- 确认配对密码正确（0000 或 1234）
- 删除已配对设备后重新配对
- 检查波特率是否为9600

**问题：收到数据但无法显示**
- 确认JSON格式是否正确
- 查看应用日志查看解析错误
- 检查 [bluetooth_service.dart](file:///workspace/lib/services/bluetooth_service.dart#L176-L196)

## 📁 文件说明

- `esp8266_bluetooth.ino` - 主代码文件
- `README.md` - 本文档

## 🎯 与原始代码的区别

| 项目 | 原始代码 | 修正后 |
|------|---------|--------|
| 温度字段 | `temp` | `temperature` |
| 湿度字段 | `humi` | `humidity` |
| 设备ID | 无 | `device_id` |
| 时间戳 | 无 | `timestamp` |
| 数据包装 | 直接对象 | `data` 对象内 |

这个修正后的版本与你的Flutter应用完全兼容！

## ✅ 版本历史

- v1.0 - 初始版本，与Flutter应用完全兼容

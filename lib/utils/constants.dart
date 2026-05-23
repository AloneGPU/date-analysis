class AppConstants {
  static const String appName = '数据监控助手';
  static const String appVersion = '1.0.0';
  
  static const int maxRecentData = 100;
  static const int maxHistoryData = 1000;
  static const int dataRetentionDays = 30;
  
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const int maxConnectionRetries = 3;
  static const Duration reconnectDelay = Duration(seconds: 2);
  
  static const Duration heartbeatInterval = Duration(seconds: 30);
  
  static const String defaultMqttBroker = 'broker.emqx.io';
  static const int defaultMqttPort = 1883;
  static const String defaultMqttTopic = 'sensor/data';
  
  static const String defaultWifiHost = '192.168.1.100';
  static const int defaultWifiPort = 8080;
  
  static const String databaseName = 'sensor_data.db';
  static const int databaseVersion = 2;
  
  static const List<String> supportedDataKeys = [
    'temperature',
    'humidity',
    'voltage',
    'current',
    'pressure',
    'altitude',
  ];
  
  static const Map<String, String> dataKeyLabels = {
    'temperature': '温度',
    'humidity': '湿度',
    'voltage': '电压',
    'current': '电流',
    'pressure': '压力',
    'altitude': '海拔',
  };
  
  static const Map<String, String> dataKeyUnits = {
    'temperature': '°C',
    'humidity': '%',
    'voltage': 'V',
    'current': 'A',
    'pressure': 'hPa',
    'altitude': 'm',
  };
}

class AppColors {
  static const int primaryValue = 0xFF2196F3;
  static const int successValue = 0xFF4CAF50;
  static const int warningValue = 0xFFFF9800;
  static const int errorValue = 0xFFF44336;
  static const int infoValue = 0xFF2196F3;
  
  static const List<int> chartColors = [
    0xFF2196F3,
    0xFF4CAF50,
    0xFFFF9800,
    0xFF9C27B0,
    0xFFF44336,
    0xFF009688,
    0xFFE91E63,
    0xFFFFEB3B,
  ];
}

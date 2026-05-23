import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/ai_config.dart';
import '../models/sensor_data.dart';
import '../models/connection_config.dart';
import '../services/wifi_service.dart';
import '../services/ai_service.dart';
import '../services/mqtt_service.dart';
import '../services/bluetooth_service.dart';
import '../services/database_service.dart';
import '../services/app_settings_service.dart';

class DataProvider extends ChangeNotifier {
  final AiService _aiService = AiService();
  final MqttService _mqttService = MqttService();
  final BluetoothService _bluetoothService = BluetoothService();
  final WifiService _wifiService = WifiService();
  final DatabaseService _databaseService = DatabaseService();
  final AppSettingsService _settingsService = AppSettingsService();

  ConnectionConfig? _currentConfig;
  ConnectionConfig? _savedConfig;
  AiConfig _aiConfig = AiConfig.defaults();
  bool _isConnected = false;
  bool _autoSave = false;
  final List<SensorData> _recentData = [];
  final List<SensorData> _historicalData = [];
  String? _errorMessage;
  final int _maxRecentData = 100;

  StreamSubscription? _dataSubscription;
  StreamSubscription? _connectionSubscription;

  bool get isConnected => _isConnected;
  bool get autoSave => _autoSave;
  List<SensorData> get recentData => List.unmodifiable(_recentData);
  List<SensorData> get historicalData => List.unmodifiable(_historicalData);
  String? get errorMessage => _errorMessage;
  set errorMessage(String? value) {
    _errorMessage = value;
    notifyListeners();
  }
  ConnectionConfig? get currentConfig => _currentConfig;
  ConnectionConfig? get savedConfig => _savedConfig;
  AiConfig get aiConfig => _aiConfig;
  DatabaseService get databaseService => _databaseService;
  List<BluetoothDevice> get discoveredBluetoothDevices => _bluetoothService.discoveredDevices;
  List<WifiDiscoveredDevice> get discoveredWifiDevices => _wifiService.discoveredDevices;

  Future<void> loadSettings() async {
    try {
      _savedConfig = await _settingsService.loadConnectionConfig();
      _autoSave = await _settingsService.loadAutoSave();
      _aiConfig = await _settingsService.loadAiConfig() ?? _aiConfig;
      notifyListeners();
    } catch (e) {
      _errorMessage = '配置加载失败: $e';
      notifyListeners();
    }
  }

  Future<void> loadAiConfig() async {
    try {
      _aiConfig = await _settingsService.loadAiConfig() ?? _aiConfig;
      notifyListeners();
    } catch (e) {
      _errorMessage = 'AI 配置加载失败: $e';
      notifyListeners();
    }
  }

  Future<void> updateAiConfig(AiConfig config) async {
    _aiConfig = config;
    try {
      await _settingsService.saveAiConfig(_aiConfig);
    } catch (e) {
      _errorMessage = 'AI 配置保存失败: $e';
    }
    notifyListeners();
  }

  Future<void> setAutoSave(bool value) async {
    _autoSave = value;
    await _settingsService.saveAutoSave(value);
    notifyListeners();
  }

  Future<void> connect(ConnectionConfig config) async {
    await _dataSubscription?.cancel();
    await _connectionSubscription?.cancel();

    _currentConfig = config;
    _errorMessage = null;
    _autoSave = config.autoSave;
    _isConnected = false;
    notifyListeners();

    try {
      switch (config.type) {
        case ConnectionType.mqtt:
          _dataSubscription = _mqttService.dataStream.listen(
            _onDataReceived,
            onError: (error) => _setConnectionError(error.toString()),
          );
          _connectionSubscription = _mqttService.connectionStream.listen(_onConnectionChanged);
          await _mqttService.connect(config);
          _isConnected = _mqttService.isConnected;
          break;
        case ConnectionType.bluetooth:
          _dataSubscription = _bluetoothService.dataStream.listen(
            _onDataReceived,
            onError: (error) => _setConnectionError(error.toString()),
          );
          _connectionSubscription = _bluetoothService.connectionStream.listen(_onConnectionChanged);
          await _bluetoothService.connect(config);
          _isConnected = _bluetoothService.isConnected;
          break;
        case ConnectionType.wifi:
          _dataSubscription = _wifiService.dataStream.listen(
            _onDataReceived,
            onError: (error) => _setConnectionError(error.toString()),
          );
          _connectionSubscription = _wifiService.connectionStream.listen(_onConnectionChanged);
          await _wifiService.connect(config);
          _isConnected = _wifiService.isConnected;
          break;
      }

      if (!_isConnected) {
        throw Exception('连接未建立，请检查地址、端口、权限或设备状态');
      }

      _savedConfig = config;
      await _settingsService.saveConnectionConfig(config);
      await _settingsService.saveAutoSave(config.autoSave);
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isConnected = false;
      _currentConfig = null;
      notifyListeners();
    }
  }

  void disconnect() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();

    switch (_currentConfig?.type) {
      case ConnectionType.mqtt:
        _mqttService.disconnect();
        break;
      case ConnectionType.bluetooth:
        _bluetoothService.disconnect();
        break;
      case ConnectionType.wifi:
        _wifiService.disconnect();
        break;
      default:
        break;
    }

    _isConnected = false;
    _currentConfig = null;
    notifyListeners();
  }

  void _setConnectionError(String message) {
    _errorMessage = message;
    _isConnected = false;
    notifyListeners();
  }

  void _onDataReceived(SensorData data) {
    _recentData.insert(0, data);
    if (_recentData.length > _maxRecentData) {
      _recentData.removeLast();
    }

    if (_autoSave) {
      unawaited(_databaseService.insertData(data));
    }

    notifyListeners();
  }

  void _onConnectionChanged(bool connected) {
    _isConnected = connected;
    notifyListeners();
  }

  Future<void> loadHistoricalData({
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    _historicalData.clear();
    _historicalData.addAll(await _databaseService.getData(
      deviceId: deviceId,
      startTime: startTime,
      endTime: endTime,
    ));
    notifyListeners();
  }

  Future<void> saveData(SensorData data) async {
    await _databaseService.insertData(data);
  }

  Future<void> saveRecentData() async {
    if (_recentData.isEmpty) {
      _errorMessage = '当前没有可保存的数据';
      notifyListeners();
      return;
    }
    await _databaseService.insertBatch(_recentData);
    _errorMessage = '已保存 ${_recentData.length} 条实时数据';
    notifyListeners();
  }

  Future<String> askAiAboutData({
    required String question,
    required List<SensorData> data,
  }) async {
    if (!_aiConfig.enabled) {
      throw Exception('请先启用 AI');
    }
    final context = _buildAiContext(data);
    final answer = await _aiService.ask(
      config: _aiConfig,
      question: question,
      context: context,
    );
    return answer;
  }

  Future<void> clearAllData() async {
    await _databaseService.deleteData();
    _recentData.clear();
    _historicalData.clear();
    notifyListeners();
  }

  Future<void> deleteOldData() async {
    final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
    await _databaseService.deleteData(beforeTime: sevenDaysAgo);
    notifyListeners();
  }

  void clearHistory() {
    _historicalData.clear();
    notifyListeners();
  }

  Future<void> exportData(String format) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final fileName = 'sensor_data_$timestamp.$format';
      final filePath = '${directory.path}/$fileName';
      
      final data = await _databaseService.getData(limit: 10000);
      
      String content;
      if (format == 'csv') {
        content = _generateCSV(data);
      } else {
        content = _generateJSON(data);
      }
      
      final file = File(filePath);
      await file.writeAsString(content);
      
      if (_errorMessage == null) {
        _errorMessage = '数据已导出到: $filePath';
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = '导出失败: $e';
      notifyListeners();
    }
  }

  String _generateCSV(List<SensorData> data) {
    if (data.isEmpty) return '';
    
    final buffer = StringBuffer();
    buffer.writeln('timestamp,device_id,data');
    
    for (var item in data) {
      final timestamp = item.timestamp.toIso8601String();
      final deviceId = item.deviceId;
      final dataStr = item.rawPayload.replaceAll('"', '""');
      buffer.writeln('"$timestamp","$deviceId","$dataStr"');
    }
    
    return buffer.toString();
  }

  String _generateJSON(List<SensorData> data) {
    final jsonData = data.map((e) => e.toJson()).toList();
    return jsonEncode(jsonData);
  }

  Future<void> discoverBluetoothDevices() async {
    await _bluetoothService.startDiscovery();
    notifyListeners();
  }

  Future<void> discoverWifiDevices({int? dataPort}) async {
    await _wifiService.startDiscovery(dataPort: dataPort);
    notifyListeners();
  }

  String _buildAiContext(List<SensorData> data) {
    if (data.isEmpty) {
      return '当前没有可分析的数据。';
    }

    final latest = data.first;
    final numericKeys = <String, List<double>>{};
    for (final item in data) {
      item.data.forEach((key, value) {
        if (value is num) {
          numericKeys.putIfAbsent(key, () => <double>[]).add(value.toDouble());
        }
      });
    }

    final summary = <String, dynamic>{
      'sampleCount': data.length,
      'latestDeviceId': latest.deviceId,
      'latestTimestamp': latest.timestamp.toIso8601String(),
      'latestData': latest.data,
      'numericSummary': numericKeys.map((key, values) {
        final average = values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;
        return MapEntry(key, {
          'min': values.reduce((a, b) => a < b ? a : b),
          'max': values.reduce((a, b) => a > b ? a : b),
          'avg': average,
        });
      }),
    };

    return const JsonEncoder.withIndent('  ').convert(summary);
  }

  @override
  void dispose() {
    disconnect();
    _mqttService.dispose();
    _bluetoothService.dispose();
    _wifiService.dispose();
    _databaseService.close();
    super.dispose();
  }
}

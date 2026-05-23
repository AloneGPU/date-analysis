import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/sensor_data.dart';
import '../models/connection_config.dart';

class BluetoothService {
  BluetoothConnection? _connection;
  final StreamController<SensorData> _dataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<List<BluetoothDevice>> _devicesController = StreamController<List<BluetoothDevice>>.broadcast();
  List<BluetoothDevice> _devices = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDiscovering = false;
  Timer? _reconnectTimer;
  StreamSubscription<BluetoothDiscoveryResult>? _discoverySubscription;
  ConnectionConfig? _lastConfig;
  static const int maxRetries = 3;
  int _retryCount = 0;

  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;
  List<BluetoothDevice> get discoveredDevices => List.unmodifiable(_devices);
  bool get isConnected => _isConnected;

  Future<void> startDiscovery() async {
    if (_isDiscovering) return;
    
    _isDiscovering = true;
    _devices = [];
    
    try {
      await _ensurePermissions();

      final enabled = await FlutterBluetoothSerial.instance.isEnabled;
      if (enabled != true) {
        final requested = await FlutterBluetoothSerial.instance.requestEnable();
        if (requested != true) {
          throw Exception('蓝牙未开启');
        }
      }

      final bondedDevices = await FlutterBluetoothSerial.instance.getBondedDevices();
      _addOrUpdateDevices(bondedDevices);

      await _discoverySubscription?.cancel();
      _discoverySubscription = FlutterBluetoothSerial.instance.startDiscovery().listen(
        (result) {
          _addOrUpdateDevices([result.device]);
        },
        onError: (error) {
          _devicesController.addError('设备发现失败: $error');
        },
      );

      await _discoverySubscription!.asFuture<void>();
    } catch (e) {
      _devicesController.addError('设备发现失败: $e');
    } finally {
      await _discoverySubscription?.cancel();
      _discoverySubscription = null;
      _isDiscovering = false;
    }
  }

  Future<void> _ensurePermissions() async {
    final bluetoothPermissions = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    final denied = bluetoothPermissions.entries.where((entry) {
      return entry.value.isDenied || entry.value.isPermanentlyDenied || entry.value.isRestricted;
    }).map((entry) => entry.key.toString()).toList();

    if (denied.isNotEmpty) {
      throw Exception('缺少蓝牙扫描权限: ${denied.join(', ')}');
    }
  }

  void _addOrUpdateDevices(List<BluetoothDevice> devices) {
    final byAddress = <String, BluetoothDevice>{
      for (final device in _devices) device.address: device,
    };

    for (final device in devices) {
      byAddress[device.address] = device;
    }

    _devices = byAddress.values.toList()
      ..sort((a, b) {
        final aName = a.name ?? '';
        final bName = b.name ?? '';
        return aName.compareTo(bName);
      });
    _devicesController.add(_devices);
  }

  Future<void> connect(ConnectionConfig config) async {
    if (_isConnecting) {
      throw Exception('连接正在进行中');
    }

    _isConnecting = true;
    _lastConfig = config;

    final settings = config.settings;
    final deviceId = settings['device_id'] as String;

    try {
      _connection = await BluetoothConnection.toAddress(deviceId);
      _isConnected = true;
      _isConnecting = false;
      _retryCount = 0;
      _connectionController.add(true);
      _listenToData();
    } catch (e) {
      _isConnecting = false;
      _handleConnectionError('蓝牙连接失败: $e');
    }
  }

  void _handleConnectionError(String message) {
    if (_retryCount < maxRetries) {
      _retryCount++;
      _scheduleReconnect();
    } else {
      _dataController.addError(message);
      _connectionController.add(false);
    }
  }

  void _scheduleReconnect() {
    if (_lastConfig == null || _retryCount >= maxRetries) return;

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: _retryCount * 2), () {
      if (_lastConfig != null && !_isConnected && !_isConnecting) {
        connect(_lastConfig!);
      }
    });
  }

  void _listenToData() {
    if (_connection == null || _connection!.input == null) return;

    _connection!.input!.listen(
      (Uint8List data) {
        try {
          final message = utf8.decode(data);
          _parseAndAddData(message);
        } catch (e) {
          print('数据解码错误: $e');
        }
      },
      onDone: () {
        _isConnected = false;
        _isConnecting = false;
        _connectionController.add(false);
        _scheduleReconnect();
      },
      onError: (error) {
        _isConnected = false;
        _isConnecting = false;
        _connectionController.add(false);
        _scheduleReconnect();
      },
    );
  }

  void _parseAndAddData(String message) {
    try {
      final trimmedMessage = message.trim();
      if (trimmedMessage.isEmpty) return;

      List<String> lines = trimmedMessage.split('\n');
      for (var line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          final jsonData = json.decode(line) as Map<String, dynamic>;
          final sensorData = SensorData.fromJson(jsonData);
          _dataController.add(sensorData);
        } catch (e) {
          print('数据解析错误: $e');
        }
      }
    } catch (e) {
      print('数据解析错误: $e');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _discoverySubscription?.cancel();
    _discoverySubscription = null;
    _isConnecting = false;
    _retryCount = 0;
    
    if (_connection != null) {
      try {
        _connection!.finish();
      } catch (e) {
        print('关闭连接错误: $e');
      }
      _connection = null;
    }
    
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _connectionController.close();
    _devicesController.close();
  }
}

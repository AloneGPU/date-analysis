import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import '../models/sensor_data.dart';
import '../models/connection_config.dart';

class WifiDiscoveredDevice {
  final String name;
  final String host;
  final int port;
  final String? deviceId;

  const WifiDiscoveredDevice({
    required this.name,
    required this.host,
    required this.port,
    this.deviceId,
  });
}

class WifiService {
  Socket? _socket;
  final StreamController<SensorData> _dataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<List<WifiDiscoveredDevice>> _devicesController = StreamController<List<WifiDiscoveredDevice>>.broadcast();
  List<WifiDiscoveredDevice> _devices = [];
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDiscovering = false;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  ConnectionConfig? _lastConfig;
  static const Duration connectionTimeout = Duration(seconds: 10);
  static const Duration discoveryTimeout = Duration(seconds: 4);
  static const int defaultDiscoveryPort = 4210;
  static const String discoveryProbe = 'DATA_MONITOR_DISCOVER';
  static const String discoveryReplyType = 'data_monitor_device';
  static const int maxRetries = 3;
  int _retryCount = 0;

  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<WifiDiscoveredDevice>> get devicesStream => _devicesController.stream;
  List<WifiDiscoveredDevice> get discoveredDevices => List.unmodifiable(_devices);
  bool get isConnected => _isConnected;

  Future<void> startDiscovery({int? dataPort}) async {
    if (_isDiscovering) return;

    _isDiscovering = true;
    _devices = [];
    _devicesController.add(_devices);

    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      socket.broadcastEnabled = true;

      final ports = <int>{
        defaultDiscoveryPort,
        if (dataPort != null && dataPort > 0) dataPort,
      };

      final probe = utf8.encode('$discoveryProbe\n');
      for (final port in ports) {
        socket.send(probe, InternetAddress('255.255.255.255'), port);
      }

      await for (final event in socket.timeout(discoveryTimeout)) {
        if (event != RawSocketEvent.read) continue;

        Datagram? datagram;
        while ((datagram = socket.receive()) != null) {
          final device = _parseDiscoveryResponse(datagram!);
          if (device != null) {
            _addOrUpdateDevice(device);
          }
        }
      }
    } on TimeoutException {
      // Discovery is complete when the listen window closes.
    } catch (e) {
      _devicesController.addError('WiFi 设备发现失败: $e');
    } finally {
      socket?.close();
      _isDiscovering = false;
    }
  }

  WifiDiscoveredDevice? _parseDiscoveryResponse(Datagram datagram) {
    try {
      final message = utf8.decode(datagram.data).trim();
      if (message.isEmpty) return null;

      if (message.startsWith('{')) {
        final jsonData = json.decode(message);
        if (jsonData is! Map<String, dynamic>) return null;
        if (jsonData['type'] != discoveryReplyType) return null;

        final host = (jsonData['host'] as String?)?.trim();
        final portValue = jsonData['port'];
        final port = portValue is int ? portValue : int.tryParse('$portValue');
        if (port == null || port <= 0) return null;

        return WifiDiscoveredDevice(
          name: ((jsonData['name'] as String?)?.trim().isNotEmpty ?? false)
              ? (jsonData['name'] as String).trim()
              : 'WiFi 设备',
          host: (host == null || host.isEmpty) ? datagram.address.address : host,
          port: port,
          deviceId: (jsonData['deviceId'] ?? jsonData['device_id'])?.toString(),
        );
      }

      if (message.startsWith('DATA_MONITOR_DEVICE')) {
        final values = <String, String>{};
        for (final part in message.split(',')) {
          final pieces = part.split('=');
          if (pieces.length == 2) {
            values[pieces.first.trim()] = pieces.last.trim();
          }
        }

        final port = int.tryParse(values['port'] ?? '');
        if (port == null || port <= 0) return null;

        return WifiDiscoveredDevice(
          name: values['name']?.isNotEmpty == true ? values['name']! : 'WiFi 设备',
          host: values['host']?.isNotEmpty == true ? values['host']! : datagram.address.address,
          port: port,
          deviceId: values['deviceId'] ?? values['device_id'],
        );
      }
    } catch (e) {
      print('WiFi 发现响应解析错误: $e');
    }

    return null;
  }

  void _addOrUpdateDevice(WifiDiscoveredDevice device) {
    final byAddress = <String, WifiDiscoveredDevice>{
      for (final item in _devices) '${item.host}:${item.port}': item,
    };

    byAddress['${device.host}:${device.port}'] = device;
    _devices = byAddress.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _devicesController.add(_devices);
  }

  Future<void> connect(ConnectionConfig config) async {
    if (_isConnecting) {
      throw Exception('连接正在进行中');
    }

    _isConnecting = true;
    _lastConfig = config;

    final settings = config.settings;
    final host = settings['host'] as String;
    final port = settings['port'] as int;

    try {
      _socket = await Socket.connect(
        host, 
        port, 
        timeout: connectionTimeout,
      );
      
      _isConnected = true;
      _isConnecting = false;
      _retryCount = 0;
      _connectionController.add(true);
      _listenToData();
      _startHeartbeat();
    } on TimeoutException {
      _isConnecting = false;
      _handleConnectionError('连接超时，请检查主机地址和端口');
    } on SocketException catch (e) {
      _isConnecting = false;
      _handleConnectionError('Socket错误: ${e.toString()}');
    } catch (e) {
      _isConnecting = false;
      _handleConnectionError('未知错误: ${e.toString()}');
    }
  }

  void _handleConnectionError(String message) {
    if (_retryCount < maxRetries) {
      _retryCount++;
      _scheduleReconnect();
    } else {
      _dataController.addError(message);
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

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected && _socket != null) {
        try {
          _socket!.write('ping\n');
        } catch (e) {
          disconnect();
        }
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _listenToData() {
    if (_socket == null) return;

    _socket!.listen(
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
        _stopHeartbeat();
        _scheduleReconnect();
      },
      onError: (error) {
        _isConnected = false;
        _isConnecting = false;
        _connectionController.add(false);
        _stopHeartbeat();
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
    _stopHeartbeat();
    _isConnecting = false;
    _retryCount = 0;
    
    if (_socket != null) {
      try {
        _socket!.destroy();
      } catch (e) {
        print('关闭连接错误: $e');
      }
      _socket = null;
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

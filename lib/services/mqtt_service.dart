import 'dart:async';
import 'dart:io';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import '../models/sensor_data.dart';
import '../models/connection_config.dart';

class MqttService {
  MqttServerClient? _client;
  final StreamController<SensorData> _dataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  bool _isConnected = false;
  bool _isConnecting = false;
  int _retryCount = 0;
  static const int maxRetries = 3;
  static const Duration connectionTimeout = Duration(seconds: 10);
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  ConnectionConfig? _lastConfig;

  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;

  Future<void> connect(ConnectionConfig config) async {
    if (_isConnecting) {
      throw Exception('连接正在进行中');
    }

    _isConnecting = true;
    _lastConfig = config;

    final settings = config.settings;
    final broker = settings['broker'] as String;
    final port = settings['port'] as int;
    final topic = settings['topic'] as String;
    final username = settings['username'] as String?;
    final password = settings['password'] as String?;

    _client = MqttServerClient(
      broker, 
      'flutter_client_${DateTime.now().millisecondsSinceEpoch}',
    );
    _client!.port = port;
    _client!.logging(on: false);
    _client!.keepAlivePeriod = 30;
    _client!.autoReconnect = false;
    _client!.resubscribeOnAutoReconnect = true;

    _client!.onConnected = () {
      _isConnected = true;
      _isConnecting = false;
      _retryCount = 0;
      _connectionController.add(true);
      _subscribeToTopic(topic);
      _startHeartbeat();
    };

    _client!.onDisconnected = () {
      _isConnected = false;
      _isConnecting = false;
      _connectionController.add(false);
      _stopHeartbeat();
      _scheduleReconnect();
    };

    _client!.onAutoReconnect = () {
      _connectionController.add(false);
    };

    _client!.onAutoReconnected = () {
      _isConnected = true;
      _connectionController.add(true);
    };

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('flutter_client_${DateTime.now().millisecondsSinceEpoch}')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);

    if (username != null && password != null) {
      connMessage.authenticateAs(username, password);
    }

    _client!.connectionMessage = connMessage;

    try {
      await _client!.connect();
      
      if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
        _isConnecting = false;
        _handleConnectionError('MQTT连接失败: ${_client!.connectionStatus?.returnCode}');
      }
    } on TimeoutException {
      _isConnecting = false;
      _handleConnectionError('连接超时，请检查网络和服务器地址');
    } on NoConnectionException catch (e) {
      _isConnecting = false;
      _handleConnectionError('MQTT连接失败: ${e.toString()}');
    } on SocketException catch (e) {
      _isConnecting = false;
      _handleConnectionError('网络错误: ${e.toString()}');
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
      if (_isConnected && _client != null) {
        try {
          if (_client!.connectionStatus?.state != MqttConnectionState.connected) {
            disconnect();
          }
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

  void _subscribeToTopic(String topic) {
    if (_client == null) return;

    _client!.subscribe(topic, MqttQos.atMostOnce);

    _client!.updates?.listen((List<MqttReceivedMessage<MqttMessage>> messages) {
      for (var message in messages) {
        try {
          final payload = message.payload as MqttPublishMessage;
          final messageString = MqttPublishPayload.bytesToStringAsString(payload.payload.message);
          _parseAndAddData(messageString);
        } catch (e) {
          print('消息解析错误: $e');
        }
      }
    });
  }

  void _parseAndAddData(String message) {
    try {
      final sensorData = SensorData.fromMessage(message);
      _dataController.add(sensorData);
    } catch (e) {
      print('数据解析错误: $e');
      _dataController.add(SensorData.fromMessage(message));
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _isConnecting = false;
    _retryCount = 0;
    _client?.disconnect();
    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _connectionController.close();
  }
}

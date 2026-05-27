import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/sensor_data.dart';
import '../models/connection_config.dart';

class SerialPortInfo {
  final String name;
  final String systemName;
  final String? description;
  final String? manufacturer;

  SerialPortInfo({
    required this.name,
    required this.systemName,
    this.description,
    this.manufacturer,
  });

  @override
  String toString() => name;
}

class SerialService {
  RandomAccessFile? _serialPort;
  final StreamController<SensorData> _dataController = StreamController<SensorData>.broadcast();
  final StreamController<bool> _connectionController = StreamController<bool>.broadcast();
  final StreamController<List<SerialPortInfo>> _portsController = StreamController<List<SerialPortInfo>>.broadcast();
  final StreamController<String> _logController = StreamController<String>.broadcast();
  
  bool _isConnected = false;
  bool _isConnecting = false;
  StreamSubscription? _readSubscription;
  Timer? _reconnectTimer;
  ConnectionConfig? _lastConfig;
  String _buffer = '';
  List<SerialPortInfo> _discoveredPorts = [];
  
  static const int maxRetries = 3;
  int _retryCount = 0;

  Stream<SensorData> get dataStream => _dataController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  Stream<List<SerialPortInfo>> get portsStream => _portsController.stream;
  Stream<String> get logStream => _logController.stream;
  bool get isConnected => _isConnected;
  List<SerialPortInfo> get discoveredPorts => List.unmodifiable(_discoveredPorts);

  Future<List<SerialPortInfo>> listPorts() async {
    final ports = <SerialPortInfo>[];
    
    try {
      if (Platform.isWindows) {
        for (int i = 0; i < 256; i++) {
          final portName = 'COM$i';
          try {
            final file = await File('\\\\.\\$portName').open(mode: FileMode.read);
            await file.close();
            ports.add(SerialPortInfo(
              name: portName,
              systemName: portName,
              description: 'Serial Port $portName',
              manufacturer: 'Unknown',
            ));
          } catch (_) {
            continue;
          }
        }
      } else if (Platform.isLinux) {
        final dir = Directory('/dev');
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is File && entity.path.startsWith('/dev/ttyUSB')) {
            ports.add(SerialPortInfo(
              name: entity.path.split('/').last,
              systemName: entity.path,
              description: 'USB Serial Port',
              manufacturer: 'Unknown',
            ));
          }
        }
      } else if (Platform.isMacOS) {
        final dir = Directory('/dev');
        final entities = await dir.list().toList();
        for (final entity in entities) {
          if (entity is File && (entity.path.startsWith('/dev/tty.usb') || entity.path.startsWith('/dev/tty.usbserial'))) {
            ports.add(SerialPortInfo(
              name: entity.path.split('/').last,
              systemName: entity.path,
              description: 'USB Serial Port',
              manufacturer: 'Unknown',
            ));
          }
        }
      }
    } catch (e) {
      _logController.add('端口扫描失败: $e');
    }
    
    _discoveredPorts = ports;
    _portsController.add(ports);
    return ports;
  }

  Future<void> startPortDiscovery() async {
    await listPorts();
    Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (!_isConnected) {
        await listPorts();
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> connect(ConnectionConfig config) async {
    if (_isConnecting) {
      _logController.add('连接正在进行中...');
      throw Exception('连接正在进行中');
    }

    _isConnecting = true;
    _lastConfig = config;
    _isConnected = false;
    _connectionController.add(false);
    _retryCount = 0;

    final settings = config.settings;
    final portName = settings['port_name'] as String;
    final baudRateIndex = settings['baud_rate'] as int? ?? 3;
    final dataBitsIndex = settings['data_bits'] as int? ?? 3;
    final stopBitsIndex = settings['stop_bits'] as int? ?? 0;
    final parityIndex = settings['parity'] as int? ?? 0;

    final baudRate = SerialBaudRate.values[baudRateIndex];
    final dataBits = SerialDataBits.values[dataBitsIndex];
    final stopBits = SerialStopBits.values[stopBitsIndex];
    final parity = SerialParity.values[parityIndex];

    await _tryConnect(portName, baudRate, dataBits, stopBits, parity);
  }

  Future<void> _tryConnect(
    String portName,
    SerialBaudRate baudRate,
    SerialDataBits dataBits,
    SerialStopBits stopBits,
    SerialParity parity,
  ) async {
    try {
      String devicePath;
      if (Platform.isWindows) {
        devicePath = '\\\\.\\$portName';
      } else {
        devicePath = '/dev/$portName';
      }

      _logController.add('尝试连接串口: $portName, 波特率: ${baudRate.value}');

      _serialPort = await File(devicePath).open(
        mode: FileMode.readWrite,
      );

      _isConnected = true;
      _isConnecting = false;
      _retryCount = 0;
      _connectionController.add(true);
      _logController.add('串口连接成功: $portName');

      _startReading();
    } on FileSystemException catch (e) {
      _isConnecting = false;
      _logController.add('连接失败: ${e.message}');
      
      if (e.osError?.errorCode == 5) {
        throw Exception('设备被占用，请检查是否有其他程序正在使用该串口');
      } else if (e.osError?.errorCode == 2) {
        throw Exception('串口不存在或已被移除');
      } else {
        throw Exception('连接失败: ${e.message}');
      }
    } catch (e) {
      _isConnecting = false;
      _logController.add('连接异常: $e');
      
      if (_retryCount < maxRetries) {
        _retryCount++;
        _logController.add('重试连接... ($_retryCount/$maxRetries)');
        _scheduleReconnect();
      } else {
        throw Exception('连接失败: $e');
      }
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

  void _startReading() {
    if (_serialPort == null) return;

    _readSubscription?.cancel();
    
    Timer.periodic(const Duration(milliseconds: 50), (timer) async {
      if (!_isConnected || _serialPort == null) {
        timer.cancel();
        return;
      }

      try {
        final bytes = await _serialPort!.read(1024);
        if (bytes.isNotEmpty) {
          _buffer += utf8.decode(bytes);
          _processBuffer();
        }
      } catch (e) {
        _logController.add('读取数据失败: $e');
        disconnect();
        timer.cancel();
      }
    });
  }

  void _processBuffer() {
    final lines = _buffer.split('\n');
    if (lines.length > 1) {
      for (int i = 0; i < lines.length - 1; i++) {
        final line = lines[i].trim();
        if (line.isNotEmpty) {
          _logController.add('收到数据: $line');
          _dataController.add(SensorData.fromMessage(line));
        }
      }
      _buffer = lines.last;
    }
  }

  Future<void> sendData(String data, {bool appendNewline = true}) async {
    if (!_isConnected || _serialPort == null) {
      throw Exception('未连接到串口');
    }

    try {
      final sendData = appendNewline ? '$data\n' : data;
      await _serialPort!.write(utf8.encode(sendData));
      await _serialPort!.flush();
      _logController.add('发送数据: $data');
    } catch (e) {
      _logController.add('发送失败: $e');
      throw Exception('发送失败: $e');
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _readSubscription?.cancel();
    _isConnecting = false;
    _retryCount = 0;

    if (_serialPort != null) {
      try {
        _serialPort!.close();
        _logController.add('串口已断开');
      } catch (e) {
        _logController.add('关闭串口失败: $e');
      }
      _serialPort = null;
    }

    _isConnected = false;
    _connectionController.add(false);
  }

  void dispose() {
    disconnect();
    _dataController.close();
    _connectionController.close();
    _portsController.close();
    _logController.close();
  }
}
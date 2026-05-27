enum ConnectionType { mqtt, bluetooth, wifi, serial }

enum SerialBaudRate {
  b1200(1200),
  b2400(2400),
  b4800(4800),
  b9600(9600),
  b14400(14400),
  b19200(19200),
  b38400(38400),
  b57600(57600),
  b115200(115200),
  b230400(230400),
  b460800(460800),
  b921600(921600);

  final int value;
  const SerialBaudRate(this.value);

  @override
  String toString() => '$value';
}

enum SerialDataBits {
  b5(5),
  b6(6),
  b7(7),
  b8(8);

  final int value;
  const SerialDataBits(this.value);

  @override
  String toString() => '$value';
}

enum SerialStopBits {
  one(1),
  onePointFive(1.5),
  two(2);

  final double value;
  const SerialStopBits(this.value);

  @override
  String toString() => value == 1.5 ? '1.5' : '$value';
}

enum SerialParity {
  none('N'),
  odd('O'),
  even('E'),
  mark('M'),
  space('S');

  final String value;
  const SerialParity(this.value);

  @override
  String toString() => value;
}

class ConnectionConfig {
  final ConnectionType type;
  final bool autoSave;
  final Map<String, dynamic> settings;

  ConnectionConfig({
    required this.type,
    this.autoSave = false,
    required this.settings,
  });

  factory ConnectionConfig.mqtt({
    required String broker,
    required int port,
    required String topic,
    String? username,
    String? password,
    bool autoSave = false,
  }) {
    return ConnectionConfig(
      type: ConnectionType.mqtt,
      autoSave: autoSave,
      settings: {
        'broker': broker,
        'port': port,
        'topic': topic,
        'username': username,
        'password': password,
      },
    );
  }

  factory ConnectionConfig.bluetooth({
    required String deviceId,
    bool autoSave = false,
  }) {
    return ConnectionConfig(
      type: ConnectionType.bluetooth,
      autoSave: autoSave,
      settings: {
        'device_id': deviceId,
      },
    );
  }

  factory ConnectionConfig.wifi({
    required String host,
    required int port,
    String protocol = 'tcp',
    bool autoSave = false,
  }) {
    return ConnectionConfig(
      type: ConnectionType.wifi,
      autoSave: autoSave,
      settings: {
        'host': host,
        'port': port,
        'protocol': protocol,
      },
    );
  }

  factory ConnectionConfig.serial({
    required String portName,
    SerialBaudRate baudRate = SerialBaudRate.b9600,
    SerialDataBits dataBits = SerialDataBits.b8,
    SerialStopBits stopBits = SerialStopBits.one,
    SerialParity parity = SerialParity.none,
    bool autoSave = false,
  }) {
    return ConnectionConfig(
      type: ConnectionType.serial,
      autoSave: autoSave,
      settings: {
        'port_name': portName,
        'baud_rate': baudRate.index,
        'data_bits': dataBits.index,
        'stop_bits': stopBits.index,
        'parity': parity.index,
      },
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type.index,
      'auto_save': autoSave,
      'settings': settings,
    };
  }

  factory ConnectionConfig.fromJson(Map<String, dynamic> json) {
    return ConnectionConfig(
      type: ConnectionType.values[json['type'] ?? 0],
      autoSave: json['auto_save'] ?? false,
      settings: Map<String, dynamic>.from(json['settings'] ?? {}),
    );
  }
}

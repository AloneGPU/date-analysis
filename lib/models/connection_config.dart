enum ConnectionType { mqtt, bluetooth, wifi }

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

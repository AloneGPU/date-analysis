import 'dart:convert';

class SensorData {
  final DateTime timestamp;
  final String deviceId;
  final Map<String, dynamic> data;
  final String rawPayload;
  final bool isStructured;

  SensorData({
    required this.timestamp,
    required this.deviceId,
    required this.data,
    required this.rawPayload,
    this.isStructured = true,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    final rawPayload = json['raw_payload']?.toString() ??
        json['raw']?.toString() ??
        jsonEncode(json);
    final dataValue = json['data'];
    final parsedData = dataValue is Map
        ? Map<String, dynamic>.from(dataValue)
        : <String, dynamic>{};
    final timestampValue = json['timestamp'];
    final timestampMs = timestampValue is int
        ? timestampValue
        : int.tryParse(timestampValue?.toString() ?? '') ??
            DateTime.now().millisecondsSinceEpoch;

    return SensorData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
      deviceId: (json['device_id'] ?? json['deviceId'] ?? 'unknown').toString(),
      data: parsedData,
      rawPayload: rawPayload,
      isStructured: json['is_structured'] == null
          ? parsedData.isNotEmpty
          : json['is_structured'] == true || json['is_structured'] == 1,
    );
  }

  factory SensorData.fromMessage(
    String message, {
    String deviceId = 'unknown',
    DateTime? timestamp,
  }) {
    final trimmed = message.trim();
    if (trimmed.isEmpty) {
      return SensorData(
        timestamp: timestamp ?? DateTime.now(),
        deviceId: deviceId,
        data: const {},
        rawPayload: message,
        isStructured: false,
      );
    }

    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map<String, dynamic>) {
        final merged = Map<String, dynamic>.from(decoded);
        merged.putIfAbsent('raw_payload', () => message);
        merged.putIfAbsent('device_id', () => deviceId);
        if (!merged.containsKey('timestamp')) {
          merged['timestamp'] = (timestamp ?? DateTime.now()).millisecondsSinceEpoch;
        }
        return SensorData.fromJson(merged);
      }
    } catch (_) {
      // Keep original payload as plain text.
    }

    return SensorData(
      timestamp: timestamp ?? DateTime.now(),
      deviceId: deviceId,
      data: {'message': message},
      rawPayload: message,
      isStructured: false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'device_id': deviceId,
      'data': data,
      'raw_payload': rawPayload,
      'is_structured': isStructured,
    };
  }

  @override
  String toString() {
    return 'SensorData(deviceId: $deviceId, timestamp: $timestamp, data: $data)';
  }
}

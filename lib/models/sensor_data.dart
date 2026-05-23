class SensorData {
  final DateTime timestamp;
  final String deviceId;
  final Map<String, dynamic> data;

  SensorData({
    required this.timestamp,
    required this.deviceId,
    required this.data,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] ?? 0),
      deviceId: json['device_id'] ?? 'unknown',
      data: Map<String, dynamic>.from(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.millisecondsSinceEpoch,
      'device_id': deviceId,
      'data': data,
    };
  }

  @override
  String toString() {
    return 'SensorData(deviceId: $deviceId, timestamp: $timestamp, data: $data)';
  }
}

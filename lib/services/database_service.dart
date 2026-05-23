import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/sensor_data.dart';

class DatabaseService {
  static Database? _database;
  String? _customPath;

  void setCustomPath(String path) {
    _customPath = path;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String dbPath;
    
    if (_customPath != null) {
      dbPath = _customPath!;
    } else {
      final defaultPath = await getDatabasesPath();
      dbPath = join(defaultPath, 'sensor_data.db');
    }

    return await openDatabase(
      dbPath,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE sensor_data(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id TEXT,
            timestamp INTEGER,
            data TEXT,
            created_at INTEGER DEFAULT (strftime('%s', 'now'))
          )
        ''');
        await db.execute('''
          CREATE INDEX idx_timestamp ON sensor_data(timestamp)
        ''');
        await db.execute('''
          CREATE INDEX idx_device_id ON sensor_data(device_id)
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute('ALTER TABLE sensor_data ADD COLUMN created_at INTEGER DEFAULT (strftime(\'%s\', \'now\'))');
          await db.execute('CREATE INDEX idx_timestamp ON sensor_data(timestamp)');
          await db.execute('CREATE INDEX idx_device_id ON sensor_data(device_id)');
        }
      },
    );
  }

  Future<void> insertData(SensorData data) async {
    final db = await database;
    await db.insert(
      'sensor_data',
      {
        'device_id': data.deviceId,
        'timestamp': data.timestamp.millisecondsSinceEpoch,
        'data': jsonEncode(data.data),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> insertBatch(List<SensorData> dataList) async {
    final db = await database;
    final batch = db.batch();
    
    for (var data in dataList) {
      batch.insert(
        'sensor_data',
        {
          'device_id': data.deviceId,
          'timestamp': data.timestamp.millisecondsSinceEpoch,
          'data': jsonEncode(data.data),
        },
      );
    }
    
    await batch.commit(noResult: true);
  }

  Future<List<SensorData>> getData({
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
    int? offset,
  }) async {
    final db = await database;
    String? whereClause;
    List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause = 'device_id = ?';
      whereArgs.add(deviceId);
    }

    if (startTime != null) {
      whereClause = whereClause != null ? '$whereClause AND timestamp >= ?' : 'timestamp >= ?';
      whereArgs.add(startTime.millisecondsSinceEpoch);
    }

    if (endTime != null) {
      whereClause = whereClause != null ? '$whereClause AND timestamp <= ?' : 'timestamp <= ?';
      whereArgs.add(endTime.millisecondsSinceEpoch);
    }

    final List<Map<String, dynamic>> maps = await db.query(
      'sensor_data',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: limit,
      offset: offset,
    );

    return maps.map((map) {
      final dataStr = map['data'] as String;
      final dataMap = _parseDataString(dataStr);
      return SensorData(
        deviceId: map['device_id'] as String,
        timestamp: DateTime.fromMillisecondsSinceEpoch(map['timestamp'] as int),
        data: dataMap,
      );
    }).toList();
  }

  Map<String, dynamic> _parseDataString(String dataStr) {
    try {
      final decoded = jsonDecode(dataStr);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Fallback for legacy string payloads.
    }

    final map = <String, dynamic>{};
    final pairs = dataStr.replaceAll('{', '').replaceAll('}', '').split(', ');
    for (var pair in pairs) {
      final keyValue = pair.split(': ');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();
        map[key] = num.tryParse(value) ?? value;
      }
    }
    return map;
  }

  Future<Map<String, dynamic>> getStatistics({
    String? deviceId,
    DateTime? startTime,
    DateTime? endTime,
  }) async {
    final db = await database;
    String whereClause = '1=1';
    List<dynamic> whereArgs = [];

    if (deviceId != null) {
      whereClause += ' AND device_id = ?';
      whereArgs.add(deviceId);
    }

    if (startTime != null) {
      whereClause += ' AND timestamp >= ?';
      whereArgs.add(startTime.millisecondsSinceEpoch);
    }

    if (endTime != null) {
      whereClause += ' AND timestamp <= ?';
      whereArgs.add(endTime.millisecondsSinceEpoch);
    }

    final result = await db.rawQuery('''
      SELECT 
        COUNT(*) as total_count,
        MIN(timestamp) as earliest_timestamp,
        MAX(timestamp) as latest_timestamp,
        COUNT(DISTINCT device_id) as device_count
      FROM sensor_data
      WHERE $whereClause
    ''', whereArgs);

    if (result.isNotEmpty) {
      final first = result.first;
      return {
        'total_count': first['total_count'] ?? 0,
        'earliest_timestamp': first['earliest_timestamp'],
        'latest_timestamp': first['latest_timestamp'],
        'device_count': first['device_count'] ?? 0,
      };
    }
    
    return {
      'total_count': 0,
      'earliest_timestamp': null,
      'latest_timestamp': null,
      'device_count': 0,
    };
  }

  Future<void> deleteData({String? deviceId, DateTime? beforeTime}) async {
    final db = await database;
    
    if (beforeTime != null) {
      await db.delete(
        'sensor_data',
        where: 'timestamp < ?',
        whereArgs: [beforeTime.millisecondsSinceEpoch],
      );
    } else if (deviceId != null) {
      await db.delete(
        'sensor_data',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    } else {
      await db.delete('sensor_data');
    }
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  Future<String> exportToJson() async {
    final data = await getData(limit: 10000);
    final jsonData = data.map((e) => e.toJson()).toList();
    return jsonEncode(jsonData);
  }

  Future<int> getDataCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM sensor_data');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}

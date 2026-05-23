import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/connection_config.dart';
import '../models/ai_config.dart';

class AppSettingsService {
  Future<File> _settingsFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/app_settings.json');
  }

  Future<Map<String, dynamic>> _readJson() async {
    final file = await _settingsFile();
    if (!await file.exists()) return {};
    try {
      final content = await file.readAsString();
      final decoded = jsonDecode(content);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return {};
  }

  Future<void> saveConnectionConfig(ConnectionConfig? config) async {
    final jsonData = await _readJson();
    jsonData['connection_config'] = config?.toJson();
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(jsonData));
  }

  Future<ConnectionConfig?> loadConnectionConfig() async {
    final jsonData = await _readJson();
    final config = jsonData['connection_config'];
    if (config is Map<String, dynamic>) {
      return ConnectionConfig.fromJson(config);
    }
    return null;
  }

  Future<void> saveAutoSave(bool value) async {
    final jsonData = await _readJson();
    jsonData['auto_save'] = value;
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(jsonData));
  }

  Future<bool> loadAutoSave() async {
    final jsonData = await _readJson();
    return jsonData['auto_save'] == true;
  }

  Future<void> saveAiConfig(AiConfig config) async {
    final jsonData = await _readJson();
    jsonData['ai_config'] = config.toJson();
    final file = await _settingsFile();
    await file.writeAsString(jsonEncode(jsonData));
  }

  Future<AiConfig?> loadAiConfig() async {
    final jsonData = await _readJson();
    final config = jsonData['ai_config'];
    if (config is Map<String, dynamic>) {
      return AiConfig.fromJson(config);
    }
    return null;
  }
}

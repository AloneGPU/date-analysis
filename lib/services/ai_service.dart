import 'dart:convert';
import 'dart:io';

import '../models/ai_config.dart';

class AiService {
  Future<String> ask({
    required AiConfig config,
    required String question,
    required String context,
  }) async {
    if (config.endpoint.trim().isEmpty) {
      throw Exception('AI 接口地址不能为空');
    }

    final uri = Uri.parse(config.endpoint.trim());
    final client = HttpClient();

    try {
      final request = await client.postUrl(uri);
      request.headers.contentType = ContentType.json;
      if (config.apiKey.trim().isNotEmpty) {
        request.headers.set(HttpHeaders.authorizationHeader, 'Bearer ${config.apiKey.trim()}');
      }

      final payload = <String, dynamic>{
        'model': config.model,
        'temperature': config.temperature,
        'max_tokens': config.maxTokens,
        'messages': [
          {'role': 'system', 'content': config.systemPrompt},
          {
            'role': 'user',
            'content': '数据上下文:\n$context\n\n用户问题:\n$question',
          },
        ],
      };

      request.write(jsonEncode(payload));
      final response = await request.close();
      final responseText = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('AI 请求失败(${response.statusCode}): $responseText');
      }

      final decoded = jsonDecode(responseText);
      if (decoded is Map<String, dynamic>) {
        final choices = decoded['choices'];
        if (choices is List && choices.isNotEmpty) {
          final first = choices.first;
          if (first is Map<String, dynamic>) {
            final message = first['message'];
            if (message is Map<String, dynamic>) {
              final content = message['content'];
              if (content is String && content.trim().isNotEmpty) {
                return content.trim();
              }
            }
          }
        }

        final content = decoded['content'];
        if (content is String && content.trim().isNotEmpty) {
          return content.trim();
        }
      }

      throw Exception('AI 返回格式不支持');
    } finally {
      client.close(force: true);
    }
  }
}

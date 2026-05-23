class AiConfig {
  final String endpoint;
  final String apiKey;
  final String model;
  final String systemPrompt;
  final double temperature;
  final int maxTokens;
  final bool enabled;

  const AiConfig({
    required this.endpoint,
    required this.apiKey,
    required this.model,
    required this.systemPrompt,
    required this.temperature,
    required this.maxTokens,
    required this.enabled,
  });

  factory AiConfig.defaults() {
    return const AiConfig(
      endpoint: 'https://api.openai.com/v1/chat/completions',
      apiKey: '',
      model: 'gpt-4o-mini',
      systemPrompt: '你是一个工业数据分析助手，擅长分析单片机和嵌入式采集数据。请结合上下文、趋势和异常点给出简洁、可执行的建议。',
      temperature: 0.2,
      maxTokens: 800,
      enabled: false,
    );
  }

  AiConfig copyWith({
    String? endpoint,
    String? apiKey,
    String? model,
    String? systemPrompt,
    double? temperature,
    int? maxTokens,
    bool? enabled,
  }) {
    return AiConfig(
      endpoint: endpoint ?? this.endpoint,
      apiKey: apiKey ?? this.apiKey,
      model: model ?? this.model,
      systemPrompt: systemPrompt ?? this.systemPrompt,
      temperature: temperature ?? this.temperature,
      maxTokens: maxTokens ?? this.maxTokens,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'apiKey': apiKey,
      'model': model,
      'systemPrompt': systemPrompt,
      'temperature': temperature,
      'maxTokens': maxTokens,
      'enabled': enabled,
    };
  }

  factory AiConfig.fromJson(Map<String, dynamic> json) {
    return AiConfig(
      endpoint: json['endpoint'] as String? ?? AiConfig.defaults().endpoint,
      apiKey: json['apiKey'] as String? ?? '',
      model: json['model'] as String? ?? AiConfig.defaults().model,
      systemPrompt: json['systemPrompt'] as String? ?? AiConfig.defaults().systemPrompt,
      temperature: (json['temperature'] as num?)?.toDouble() ?? AiConfig.defaults().temperature,
      maxTokens: json['maxTokens'] as int? ?? AiConfig.defaults().maxTokens,
      enabled: json['enabled'] as bool? ?? false,
    );
  }
}

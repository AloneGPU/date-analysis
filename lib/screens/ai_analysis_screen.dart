import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/ai_config.dart';
import '../models/sensor_data.dart';
import '../providers/data_provider.dart';

enum AiDataScope { recent, history }

class AiAnalysisScreen extends StatefulWidget {
  const AiAnalysisScreen({super.key});

  @override
  State<AiAnalysisScreen> createState() => _AiAnalysisScreenState();
}

class _AiAnalysisScreenState extends State<AiAnalysisScreen> {
  final TextEditingController _endpointController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();

  AiDataScope _scope = AiDataScope.recent;
  bool _ready = false;
  bool _loading = false;
  String _answer = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<DataProvider>();
      await provider.loadAiConfig();
      if (!mounted) return;
      final config = provider.aiConfig;
      _endpointController.text = config.endpoint;
      _apiKeyController.text = config.apiKey;
      _modelController.text = config.model;
      _promptController.text = config.systemPrompt;
      setState(() {
        _ready = true;
      });
    });
  }

  @override
  void dispose() {
    _endpointController.dispose();
    _apiKeyController.dispose();
    _modelController.dispose();
    _promptController.dispose();
    _questionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 数据分析'),
        actions: [
          IconButton(
            tooltip: '保存配置',
            icon: const Icon(Icons.save),
            onPressed: _ready ? _saveConfig : null,
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          final data = _scope == AiDataScope.recent && provider.recentData.isNotEmpty
              ? provider.recentData
              : provider.historicalData.isNotEmpty
                  ? provider.historicalData
                  : provider.recentData;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildConfigCard(provider),
                const SizedBox(height: 16),
                _buildScopeCard(provider),
                const SizedBox(height: 16),
                _buildQuestionCard(provider, data),
                const SizedBox(height: 16),
                _buildAnswerCard(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildConfigCard(DataProvider provider) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 接口设置', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _endpointController,
              decoration: const InputDecoration(
                labelText: '接口地址',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _apiKeyController,
              decoration: const InputDecoration(
                labelText: 'API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _modelController,
              decoration: const InputDecoration(
                labelText: '模型名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '系统提示词',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('启用 AI'),
              subtitle: const Text('开启后可对采集数据进行问答和分析'),
              value: provider.aiConfig.enabled,
              onChanged: (value) {
                provider.updateAiConfig(provider.aiConfig.copyWith(enabled: value));
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScopeCard(DataProvider provider) {
    final recentCount = provider.recentData.length;
    final historyCount = provider.historicalData.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('数据来源', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            SegmentedButton<AiDataScope>(
              segments: [
                ButtonSegment(
                  value: AiDataScope.recent,
                  label: Text('实时数据 ($recentCount)'),
                  icon: const Icon(Icons.bolt),
                ),
                ButtonSegment(
                  value: AiDataScope.history,
                  label: Text('历史数据 ($historyCount)'),
                  icon: const Icon(Icons.history),
                ),
              ],
              selected: {_scope},
              onSelectionChanged: (value) {
                setState(() {
                  _scope = value.first;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionCard(DataProvider provider, List<SensorData> data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('询问与分析', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: _questionController,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: '输入你的问题',
                hintText: '例如：最近 50 条数据有没有异常趋势？',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: _loading || data.isEmpty ? null : () => _analyze(provider, data, '请总结这批数据的主要趋势、异常点和建议。'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('自动分析'),
                ),
                OutlinedButton.icon(
                  onPressed: _loading || data.isEmpty ? null : () => _analyze(provider, data, _questionController.text.trim()),
                  icon: const Icon(Icons.chat),
                  label: const Text('发送问题'),
                ),
              ],
            ),
            if (data.isEmpty) ...[
              const SizedBox(height: 12),
              const Text('当前没有可用于分析的数据。', style: TextStyle(color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnswerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('AI 输出', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else
              SelectableText(
                _answer.isEmpty ? '这里会显示 AI 的分析结果。' : _answer,
                style: const TextStyle(height: 1.5),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveConfig() async {
    final provider = context.read<DataProvider>();
    final updated = AiConfig(
      endpoint: _endpointController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      model: _modelController.text.trim(),
      systemPrompt: _promptController.text.trim(),
      temperature: provider.aiConfig.temperature,
      maxTokens: provider.aiConfig.maxTokens,
      enabled: provider.aiConfig.enabled,
    );
    await provider.updateAiConfig(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('AI 配置已保存')));
  }

  Future<void> _analyze(DataProvider provider, List<SensorData> data, String question) async {
    final text = question.trim().isEmpty ? '请分析当前采集数据是否存在异常。' : question.trim();

    setState(() {
      _loading = true;
      _answer = '';
    });

    try {
      final result = await provider.askAiAboutData(
        question: text,
        data: data,
      );
      if (!mounted) return;
      setState(() {
        _answer = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _answer = 'AI 分析失败: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }
}

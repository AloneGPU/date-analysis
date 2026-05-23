import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/data_provider.dart';

class StorageSettingsScreen extends StatefulWidget {
  const StorageSettingsScreen({super.key});

  @override
  State<StorageSettingsScreen> createState() => _StorageSettingsScreenState();
}

class _StorageSettingsScreenState extends State<StorageSettingsScreen> {
  final TextEditingController _pathController = TextEditingController();
  bool _autoSave = false;
  int _dataCount = 0;
  Map<String, dynamic> _statistics = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _autoSave = context.read<DataProvider>().autoSave;
      });
    });
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final provider = context.read<DataProvider>();
      final dbService = provider.databaseService;
      final count = await dbService.getDataCount();
      final stats = await dbService.getStatistics();

      setState(() {
        _dataCount = count;
        _statistics = stats;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('加载统计失败: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('存储设置'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatisticsCard(),
            const SizedBox(height: 24),
            _buildAutoSaveSwitch(),
            const SizedBox(height: 24),
            _buildDataManagementSection(),
            const SizedBox(height: 24),
            _buildExportSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatisticsCard() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final dateFormat = DateFormat('yyyy-MM-dd HH:mm');
    String? earliestTime;
    String? latestTime;

    if (_statistics['earliest_timestamp'] != null) {
      earliestTime = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(_statistics['earliest_timestamp'] as int),
      );
    }

    if (_statistics['latest_timestamp'] != null) {
      latestTime = dateFormat.format(
        DateTime.fromMillisecondsSinceEpoch(_statistics['latest_timestamp'] as int),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics, color: Colors.blue),
                const SizedBox(width: 8),
                const Text(
                  '数据统计',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadStatistics,
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            _buildStatRow('数据总数', '$_dataCount 条'),
            _buildStatRow('设备数量', '${_statistics['device_count'] ?? 0} 个'),
            _buildStatRow('最早数据', earliestTime ?? '暂无'),
            _buildStatRow('最新数据', latestTime ?? '暂无'),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildAutoSaveSwitch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '自动存储',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: const Text('接收数据时自动保存'),
              subtitle: const Text('开启后，接收到的数据将自动保存到本地数据库'),
              value: _autoSave,
              onChanged: (value) {
                setState(() {
                  _autoSave = value;
                });
                context.read<DataProvider>().setAutoSave(value);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据管理',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.delete_sweep, color: Colors.red),
              title: const Text('清空所有数据'),
              subtitle: const Text('删除数据库中的所有历史数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showClearDataDialog(),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('删除7天前的数据'),
              subtitle: const Text('自动清理过期数据'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showDeleteOldDataDialog(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExportSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据导出',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.file_download, color: Colors.blue),
              title: const Text('导出为CSV'),
              subtitle: const Text('导出数据为CSV格式文件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportData('csv'),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.code, color: Colors.green),
              title: const Text('导出为JSON'),
              subtitle: const Text('导出数据为JSON格式文件'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _exportData('json'),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空所有数据'),
        content: const Text(
          '确定要删除所有历史数据吗？此操作不可撤销。\n\n建议：在清空前先导出数据备份。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<DataProvider>().clearAllData();
              await _loadStatistics();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('数据已清空')),
                );
              }
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteOldDataDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除旧数据'),
        content: const Text('确定要删除7天前的所有数据吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await context.read<DataProvider>().deleteOldData();
              await _loadStatistics();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('旧数据已删除')),
                );
              }
            },
            child: const Text('确认删除'),
          ),
        ],
      ),
    );
  }

  void _exportData(String format) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('正在导出$format格式数据...')),
    );
    context.read<DataProvider>().exportData(format);
  }

  @override
  void dispose() {
    _pathController.dispose();
    super.dispose();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/connection_config.dart';
import '../models/sensor_data.dart';
import '../providers/data_provider.dart';
import '../widgets/real_time_chart.dart';
import '../widgets/data_card.dart';
import '../widgets/connection_status.dart';
import 'ai_analysis_screen.dart';
import 'connection_screen.dart';
import 'data_history_screen.dart';
import 'data_visualization_screen.dart';
import 'raw_data_screen.dart';
import 'storage_settings_screen.dart';
import 'help_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _selectedDataKey = 'temperature';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据监控'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '帮助',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HelpScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_alt),
            tooltip: 'AI 分析',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AiAnalysisScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: '历史数据',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DataHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.subject),
            tooltip: '原始数据',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RawDataScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.storage),
            tooltip: '存储设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const StorageSettingsScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: '连接设置',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ConnectionScreen()),
              );
            },
          ),
        ],
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (provider.errorMessage != null && provider.errorMessage!.contains('导出')) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(provider.errorMessage!)),
              );
              provider.errorMessage = null;
            });
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: ConnectionStatus(
                  isConnected: provider.isConnected,
                  connectionType: _getConnectionTypeName(provider),
                ),
              ),
              if (!provider.isConnected)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.wifi_off, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text(
                          '未连接设备',
                          style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '点击右上角设置进行连接',
                          style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildDataCards(provider),
                _buildDataKeySelector(provider),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: _collectNumericKeys(provider.recentData).isEmpty
                        ? const Center(child: Text('当前数据没有数值字段，请查看原始数据'))
                        : RealTimeChart(
                            data: provider.recentData,
                            dataKey: _resolveDataKey(provider),
                          ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const DataVisualizationScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.insert_chart),
                          label: const Text('查看更多图表'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await provider.saveRecentData();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.errorMessage ?? '已保存当前实时数据')),
                            );
                          },
                          icon: const Icon(Icons.save_alt),
                          label: const Text('保存当前数据'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ConnectionScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  String _getConnectionTypeName(DataProvider provider) {
    switch (provider.currentConfig?.type) {
      case ConnectionType.mqtt:
        return 'MQTT';
      case ConnectionType.bluetooth:
        return '蓝牙';
      case ConnectionType.wifi:
        return 'WiFi';
      default:
        return '';
    }
  }

  Widget _buildDataCards(DataProvider provider) {
    if (provider.recentData.isEmpty) return const SizedBox.shrink();

    final latestData = provider.recentData.first;
    final dataKeys = _collectDisplayKeys(provider.recentData);

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: dataKeys.length,
        itemBuilder: (context, index) {
          final key = dataKeys[index];
          final value = latestData.data[key];
          return SizedBox(
            width: 120,
            child: DataCard(
              title: key,
              value: value?.toString() ?? '--',
              icon: _getIconForDataKey(key),
              color: _getColorForIndex(index),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDataKeySelector(DataProvider provider) {
    final dataKeys = provider.recentData.isNotEmpty
        ? _collectNumericKeys(provider.recentData)
        : ['temperature', 'humidity', 'voltage', 'current'];
    if (dataKeys.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text('当前数据没有可绘制的数值字段'),
      );
    }
    final selectedKey = _resolveDataKey(provider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Text('图表显示: ', style: TextStyle(fontSize: 14)),
          Expanded(
            child: DropdownButton<String>(
              value: selectedKey,
              isExpanded: true,
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    _selectedDataKey = newValue;
                  });
                }
              },
              items: dataKeys.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForDataKey(String key) {
    switch (key.toLowerCase()) {
      case 'temperature':
        return Icons.thermostat;
      case 'humidity':
        return Icons.water_drop;
      case 'voltage':
        return Icons.electric_bolt;
      case 'current':
        return Icons.electrical_services;
      default:
        return Icons.sensors;
    }
  }

  Color _getColorForIndex(int index) {
    final colors = [Colors.blue, Colors.green, Colors.orange, Colors.purple, Colors.red];
    return colors[index % colors.length];
  }

  String _resolveDataKey(DataProvider provider) {
    if (provider.recentData.isEmpty) {
      return _selectedDataKey;
    }
    final dataKeys = _collectNumericKeys(provider.recentData);
    if (dataKeys.contains(_selectedDataKey)) {
      return _selectedDataKey;
    }
    return dataKeys.isNotEmpty ? dataKeys.first : _selectedDataKey;
  }

  List<String> _collectNumericKeys(List<SensorData> data) {
    final keys = <String>{};
    for (final item in data) {
      item.data.forEach((key, value) {
        if (value is num) {
          keys.add(key);
        }
      });
    }
    return keys.toList();
  }

  List<String> _collectDisplayKeys(List<SensorData> data) {
    final keys = <String>{};
    for (final item in data) {
      keys.addAll(item.data.keys);
    }
    return keys.toList();
  }
}

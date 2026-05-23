import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sensor_data.dart';
import '../providers/data_provider.dart';
import '../widgets/real_time_chart.dart';
import '../widgets/bar_chart_widget.dart';
import '../widgets/pie_chart_widget.dart';
import '../widgets/gauge_widget.dart';
import '../widgets/radar_chart_widget.dart';

class DataVisualizationScreen extends StatefulWidget {
  const DataVisualizationScreen({super.key});

  @override
  State<DataVisualizationScreen> createState() => _DataVisualizationScreenState();
}

class _DataVisualizationScreenState extends State<DataVisualizationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedDataKey = 'temperature';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('数据可视化'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: '折线图', icon: Icon(Icons.show_chart)),
            Tab(text: '柱状图', icon: Icon(Icons.bar_chart)),
            Tab(text: '饼图', icon: Icon(Icons.pie_chart)),
            Tab(text: '仪表盘', icon: Icon(Icons.dashboard)),
            Tab(text: '雷达图', icon: Icon(Icons.radar)),
          ],
        ),
      ),
      body: Consumer<DataProvider>(
        builder: (context, provider, child) {
          if (!provider.isConnected || provider.recentData.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.insert_chart_outlined, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    '暂无数据',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '请先连接设备并接收数据',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          if (_collectNumericKeys(provider.recentData).isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.subject, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('当前数据没有数值字段', style: TextStyle(fontSize: 18, color: Colors.grey)),
                  SizedBox(height: 8),
                  Text('请在原始数据页面查看字符串或文本数据', style: TextStyle(fontSize: 14, color: Colors.grey)),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildLineChartView(provider),
              _buildBarChartView(provider),
              _buildPieChartView(provider),
              _buildGaugeView(provider),
              _buildRadarChartView(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildLineChartView(DataProvider provider) {
    final dataKey = _resolveDataKey(provider.recentData);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDataKeySelector(provider),
          const SizedBox(height: 16),
          Expanded(
            child: RealTimeChart(
              data: provider.recentData,
              dataKey: dataKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChartView(DataProvider provider) {
    final dataKey = _resolveDataKey(provider.recentData);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildDataKeySelector(provider),
          const SizedBox(height: 16),
          Expanded(
            child: BarChartWidget(
              data: provider.recentData,
              dataKey: dataKey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartView(DataProvider provider) {
    if (provider.recentData.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }
    final Map<String, num> pieData = {};

    for (final item in provider.recentData) {
      item.data.forEach((key, value) {
        if (value is num && !pieData.containsKey(key)) {
          pieData[key] = value;
        }
      });
      if (pieData.length >= 8) {
        break;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: PieChartWidget(
        data: pieData,
        title: '最新数据分布',
      ),
    );
  }

  Widget _buildGaugeView(DataProvider provider) {
    if (provider.recentData.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final latestData = _latestNumericValues(provider.recentData);
    final dataKeys = latestData.keys.toList();
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: dataKeys.length.clamp(0, 6),
        itemBuilder: (context, index) {
          final key = dataKeys[index];
          final value = latestData[key]?.toDouble() ?? 0;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GaugeWidget(
                value: value,
                label: key,
                color: colors[index % colors.length],
                maxValue: _getDynamicMax(provider.recentData, key),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRadarChartView(DataProvider provider) {
    if (provider.recentData.isEmpty) {
      return const Center(child: Text('暂无数据'));
    }

    final Map<String, num> radarData = _latestNumericValues(provider.recentData);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: RadarChartWidget(
        data: radarData,
        title: '多维数据对比',
      ),
    );
  }

  Widget _buildDataKeySelector(DataProvider provider) {
    if (provider.recentData.isEmpty) return const SizedBox.shrink();

    final dataKeys = _collectNumericKeys(provider.recentData);
    if (dataKeys.isEmpty) return const SizedBox.shrink();
    final selectedKey = _resolveDataKey(provider.recentData);

    return Row(
      children: [
        const Text('选择数据: ', style: TextStyle(fontSize: 14)),
        const SizedBox(width: 8),
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
    );
  }

  String _resolveDataKey(List<SensorData> data) {
    if (data.isEmpty) return _selectedDataKey;
    final keys = _collectNumericKeys(data);
    if (keys.isEmpty) return _selectedDataKey;
    if (keys.contains(_selectedDataKey)) {
      return _selectedDataKey;
    }
    return keys.isNotEmpty ? keys.first : _selectedDataKey;
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

  Map<String, num> _latestNumericValues(List<SensorData> data) {
    final values = <String, num>{};
    for (final item in data) {
      item.data.forEach((key, value) {
        if (value is num && !values.containsKey(key)) {
          values[key] = value;
        }
      });
      if (values.length >= 8) {
        break;
      }
    }
    return values;
  }

  double _getDynamicMax(List<SensorData> data, String key) {
    final values = data
        .map((item) => item.data[key])
        .whereType<num>()
        .map((value) => value.toDouble())
        .toList();
    if (values.isEmpty) return 100;
    final max = values.reduce((a, b) => a > b ? a : b).abs();
    return max == 0 ? 100 : max * 1.2;
  }
}

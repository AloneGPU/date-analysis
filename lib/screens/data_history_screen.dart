import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/sensor_data.dart';
import '../providers/data_provider.dart';
import '../widgets/real_time_chart.dart';

class DataHistoryScreen extends StatefulWidget {
  const DataHistoryScreen({super.key});

  @override
  State<DataHistoryScreen> createState() => _DataHistoryScreenState();
}

class _DataHistoryScreenState extends State<DataHistoryScreen> {
  DateTime _startTime = DateTime.now().subtract(const Duration(hours: 1));
  DateTime _endTime = DateTime.now();
  String _selectedDataKey = 'temperature';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    context.read<DataProvider>().loadHistoricalData(
          startTime: _startTime,
          endTime: _endTime,
        );
  }

  Future<void> _selectDateTime({required bool isStart}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startTime : _endTime,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );

    if (picked != null && mounted) {
      final TimeOfDay? timePicked = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(isStart ? _startTime : _endTime),
      );

      if (timePicked != null && mounted) {
        setState(() {
          final dateTime = DateTime(
            picked.year,
            picked.month,
            picked.day,
            timePicked.hour,
            timePicked.minute,
          );
          if (isStart) {
            _startTime = dateTime;
          } else {
            _endTime = dateTime;
          }
        });
        _loadData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('历史数据'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              _showClearDialog();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTimeRangeSelector(),
          _buildDataKeySelector(),
          Expanded(
            child: Consumer<DataProvider>(
              builder: (context, provider, child) {
                if (provider.historicalData.isEmpty) {
                  return const Center(
                    child: Text('该时间范围内无数据'),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      if (_collectNumericKeys(provider.historicalData).isNotEmpty)
                        Expanded(
                          flex: 2,
                          child: RealTimeChart(
                            data: provider.historicalData,
                            dataKey: _resolveDataKey(_collectNumericKeys(provider.historicalData)),
                            lineColor: Colors.orange,
                          ),
                        )
                      else
                        const Expanded(
                          flex: 2,
                          child: Center(child: Text('该时间范围内的数据没有数值字段')),
                        ),
                      const SizedBox(height: 16),
                      Expanded(
                        flex: 1,
                        child: _buildDataTable(provider),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangeSelector() {
    final dateFormat = DateFormat('MM/dd HH:mm');

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('时间范围', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDateTime(isStart: true),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dateFormat.format(_startTime)),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('至'),
                ),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _selectDateTime(isStart: false),
                    icon: const Icon(Icons.calendar_today, size: 16),
                    label: Text(dateFormat.format(_endTime)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataKeySelector() {
    final provider = context.watch<DataProvider>();
    final data = provider.historicalData;
    final dataKeys = data.isNotEmpty ? _collectNumericKeys(data) : ['temperature', 'humidity', 'voltage', 'current'];
    if (dataKeys.isEmpty) return const SizedBox.shrink();
    final selectedKey = _resolveDataKey(dataKeys);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Text('显示数据: ', style: TextStyle(fontSize: 14)),
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

  Widget _buildDataTable(DataProvider provider) {
    return Card(
      child: ListView.builder(
        itemCount: provider.historicalData.length.clamp(0, 20),
        itemBuilder: (context, index) {
          final data = provider.historicalData[index];
          final selectedKey = _resolveDataKey(_collectNumericKeys([data]));
          final value = data.data[selectedKey];

          return ListTile(
            dense: true,
            leading: Text(
              DateFormat('HH:mm:ss').format(data.timestamp),
              style: const TextStyle(fontSize: 12),
            ),
            title: Text(
              '$value',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              '设备: ${data.deviceId}',
              style: const TextStyle(fontSize: 10),
            ),
          );
        },
      ),
    );
  }

  String _resolveDataKey(List<String> dataKeys) {
    if (dataKeys.isEmpty) return _selectedDataKey;
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

  void _showClearDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清除历史数据'),
        content: const Text('确定要清除所有历史数据吗？此操作不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              context.read<DataProvider>().clearHistory();
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class RadarChartWidget extends StatefulWidget {
  final Map<String, num> data;
  final String title;

  const RadarChartWidget({
    super.key,
    required this.data,
    this.title = '数据雷达图',
  });

  @override
  State<RadarChartWidget> createState() => _RadarChartWidgetState();
}

class _RadarChartWidgetState extends State<RadarChartWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return Column(
      children: [
        Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: RadarChart(
            RadarChartData(
              radarShape: RadarShape.polygon,
              radarBorderData: const BorderSide(color: Colors.grey, width: 1),
              gridBorderData: const BorderSide(color: Colors.grey, width: 0.5),
              tickBorderData: const BorderSide(color: Colors.transparent),
              tickCount: 4,
              titleTextStyle: const TextStyle(fontSize: 12, color: Colors.black),
              getTitle: (index, angle) {
                final keys = widget.data.keys.toList();
                if (index < keys.length) {
                  return RadarChartTitle(
                    text: keys[index],
                    angle: 0,
                  );
                }
                return const RadarChartTitle(text: '');
              },
              dataSets: [
                RadarDataSet(
                  fillColor: Colors.blue.withValues(alpha: 0.2),
                  borderColor: Colors.blue,
                  borderWidth: 2,
                  entryRadius: 3,
                  dataEntries: widget.data.values.map((e) {
                    return RadarEntry(value: e.toDouble());
                  }).toList(),
                ),
              ],
              titlePositionPercentageOffset: 0.2,
              radarBackgroundColor: Colors.transparent,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildDataSummary(),
      ],
    );
  }

  Widget _buildDataSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '数据摘要',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: widget.data.entries.map((entry) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${entry.key}: ',
                      style: const TextStyle(fontSize: 12),
                    ),
                    Text(
                      entry.value.toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

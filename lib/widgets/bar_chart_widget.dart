import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_data.dart';

class BarChartWidget extends StatelessWidget {
  final List<SensorData> data;
  final String dataKey;
  final Color barColor;

  const BarChartWidget({
    super.key,
    required this.data,
    required this.dataKey,
    this.barColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    final chartData = data
        .where((d) => d.data.containsKey(dataKey))
        .take(20)
        .toList()
        .reversed
        .toList();

    if (chartData.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY(chartData),
        minY: _getMinY(chartData),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (group) => Colors.blueGrey.withValues(alpha: 0.8),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final sensorData = chartData[group.x.toInt()];
              final value = sensorData.data[dataKey];
              final time = '${sensorData.timestamp.hour}:${sensorData.timestamp.minute.toString().padLeft(2, '0')}';
              return BarTooltipItem(
                '$time\n${value?.toString() ?? '--'}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= chartData.length) {
                  return const SizedBox.shrink();
                }
                final time = chartData[value.toInt()].timestamp;
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    '${time.hour}:${time.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 10),
                  ),
                );
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        barGroups: chartData.asMap().entries.map((entry) {
          return BarChartGroupData(
            x: entry.key,
            barRods: [
              BarChartRodData(
                toY: (entry.value.data[dataKey] as num?)?.toDouble() ?? 0,
                color: barColor,
                width: 16,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withValues(alpha: 0.3),
              strokeWidth: 1,
            );
          },
        ),
      ),
    );
  }

  double _getMaxY(List<SensorData> data) {
    double maxVal = 0;
    for (var d in data) {
      final val = (d.data[dataKey] as num?)?.toDouble() ?? 0;
      if (val > maxVal) maxVal = val;
    }
    return maxVal * 1.2;
  }

  double _getMinY(List<SensorData> data) {
    double minVal = double.infinity;
    for (var d in data) {
      final val = (d.data[dataKey] as num?)?.toDouble() ?? 0;
      if (val < minVal) minVal = val;
    }
    return minVal > 0 ? 0 : minVal * 1.2;
  }
}

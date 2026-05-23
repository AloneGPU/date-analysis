import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_data.dart';

class RealTimeChart extends StatelessWidget {
  final List<SensorData> data;
  final String dataKey;
  final Color lineColor;

  const RealTimeChart({
    super.key,
    required this.data,
    required this.dataKey,
    this.lineColor = Colors.blue,
  });

  @override
  Widget build(BuildContext context) {
    final chartData = data
        .where((d) => d.data.containsKey(dataKey))
        .map((d) => FlSpot(
              d.timestamp.millisecondsSinceEpoch.toDouble(),
              (d.data[dataKey] as num).toDouble(),
            ))
        .toList()
      ..sort((a, b) => a.x.compareTo(b.x));

    if (chartData.isEmpty) {
      return const Center(
        child: Text('暂无数据', style: TextStyle(color: Colors.grey)),
      );
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(show: true),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final dateTime = DateTime.fromMillisecondsSinceEpoch(value.toInt());
                return Text(
                  '${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: chartData,
            isCurved: true,
            color: lineColor,
            barWidth: 2,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(2)}',
                  TextStyle(color: Colors.white, fontSize: 12),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/weight_data.dart';

class ForceChartWidget extends StatelessWidget {
  final List<WeightDataPoint> weightHistory;
  final WeightUnit unit;

  const ForceChartWidget({
    super.key,
    required this.weightHistory,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    if (weightHistory.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final startTime = weightHistory.first.timestamp;
    final spots = weightHistory.map((point) {
      return FlSpot(
        point.getSecondsFrom(startTime),
        unit.convert(point.weight),
      );
    }).toList();

    // Calculate min/max for Y axis
    final weights = weightHistory.map((p) => unit.convert(p.weight)).toList();
    final maxWeight = weights.reduce((a, b) => a > b ? a : b);
    final minWeight = weights.reduce((a, b) => a < b ? a : b);
    final yPadding = (maxWeight - minWeight) * 0.1;
    final yMin = (minWeight - yPadding).clamp(0.0, double.infinity);
    final yMax = maxWeight + yPadding;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: (yMax - yMin) / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.1),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            axisNameWidget: Text(
              'Time (s)',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: spots.last.x > 10 ? 5 : 2,
              getTitlesWidget: (value, meta) {
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    value.toStringAsFixed(0),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            axisNameWidget: Text(
              unit.symbol,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 10,
              ),
            ),
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                String text;
                switch (unit) {
                  case WeightUnit.grams:
                    text = value.toStringAsFixed(0);
                    break;
                  case WeightUnit.kilograms:
                    text = value.toStringAsFixed(1);
                    break;
                  case WeightUnit.pounds:
                    text = value.toStringAsFixed(0);
                    break;
                }
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  child: Text(
                    text,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
        ),
        minX: 0,
        maxX: spots.last.x,
        minY: yMin,
        maxY: yMax,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: const Color(0xFF3B82F6),
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF3B82F6).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  '${spot.y.toStringAsFixed(1)} ${unit.symbol}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                );
              }).toList();
            },
          ),
        ),
      ),
      duration: Duration.zero,
    );
  }
}

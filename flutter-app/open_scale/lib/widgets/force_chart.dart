import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/weight_data.dart';

/// Time range options for the chart
enum TimeRangeOption {
  all('All Time', null),
  last30s('30 sec', 30),
  last1m('1 min', 60),
  last5m('5 min', 300),
  last10m('10 min', 600),
  custom('Custom', null);

  final String label;
  final int? seconds;
  const TimeRangeOption(this.label, this.seconds);
}

class ForceChartWidget extends StatefulWidget {
  final List<WeightDataPoint> weightHistory;
  final WeightUnit unit;
  final DateTime? connectionStartTime;

  const ForceChartWidget({
    super.key,
    required this.weightHistory,
    required this.unit,
    this.connectionStartTime,
  });

  @override
  State<ForceChartWidget> createState() => _ForceChartWidgetState();
}

class _ForceChartWidgetState extends State<ForceChartWidget> {
  TimeRangeOption _selectedRange = TimeRangeOption.last5m;
  double? _customStartSeconds;
  double? _customEndSeconds;
  bool _showCustomInputs = false;

  final _startController = TextEditingController();
  final _endController = TextEditingController();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  List<WeightDataPoint> _getFilteredData() {
    if (widget.weightHistory.isEmpty) return [];

    final connectionStart = widget.connectionStartTime ?? widget.weightHistory.first.timestamp;
    final now = DateTime.now();

    switch (_selectedRange) {
      case TimeRangeOption.all:
        return widget.weightHistory;
      case TimeRangeOption.custom:
        if (_customStartSeconds != null && _customEndSeconds != null) {
          final startTime = connectionStart.add(Duration(milliseconds: (_customStartSeconds! * 1000).round()));
          final endTime = connectionStart.add(Duration(milliseconds: (_customEndSeconds! * 1000).round()));
          return widget.weightHistory.where((p) =>
              p.timestamp.isAfter(startTime) && p.timestamp.isBefore(endTime)).toList();
        }
        return widget.weightHistory;
      default:
        if (_selectedRange.seconds != null) {
          final cutoff = now.subtract(Duration(seconds: _selectedRange.seconds!));
          return widget.weightHistory.where((p) => p.timestamp.isAfter(cutoff)).toList();
        }
        return widget.weightHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Time range selector
        _buildTimeRangeSelector(),
        if (_showCustomInputs) _buildCustomRangeInputs(),
        const SizedBox(height: 8),
        // Chart
        Expanded(child: _buildChart()),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: TimeRangeOption.values.map((option) {
          final isSelected = _selectedRange == option;
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: ChoiceChip(
              label: Text(option.label),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() {
                    _selectedRange = option;
                    _showCustomInputs = option == TimeRangeOption.custom;
                  });
                }
              },
              labelStyle: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : Colors.grey[400],
              ),
              backgroundColor: const Color(0xFF334155),
              selectedColor: const Color(0xFF3B82F6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCustomRangeInputs() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _startController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Start (sec)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _endController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'End (sec)',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              final start = double.tryParse(_startController.text);
              final end = double.tryParse(_endController.text);
              if (start != null && end != null && start < end) {
                setState(() {
                  _customStartSeconds = start;
                  _customEndSeconds = end;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
            ),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    final filteredData = _getFilteredData();

    if (filteredData.isEmpty) {
      return const Center(
        child: Text(
          'No data yet',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final connectionStart = widget.connectionStartTime ?? widget.weightHistory.first.timestamp;
    final spots = filteredData.map((point) {
      return FlSpot(
        point.timestamp.difference(connectionStart).inMilliseconds / 1000.0,
        widget.unit.convert(point.weight),
      );
    }).toList();

    // Calculate min/max for Y axis
    final weights = filteredData.map((p) => widget.unit.convert(p.weight)).toList();
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
              widget.unit.symbol,
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
                switch (widget.unit) {
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
        minX: spots.first.x,
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
                  '${spot.y.toStringAsFixed(1)} ${widget.unit.symbol}\n${spot.x.toStringAsFixed(1)}s',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
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

import 'package:flutter/material.dart';
import '../models/weight_data.dart';

class WeightDisplayWidget extends StatelessWidget {
  final double currentWeight;
  final double peakWeight;
  final WeightUnit unit;
  final VoidCallback? onTare;
  final VoidCallback onResetPeak;
  final Function(WeightUnit) onUnitChange;

  const WeightDisplayWidget({
    super.key,
    required this.currentWeight,
    required this.peakWeight,
    required this.unit,
    required this.onTare,
    required this.onResetPeak,
    required this.onUnitChange,
  });

  @override
  Widget build(BuildContext context) {
    final displayWeight = unit.convert(currentWeight);
    final displayPeak = unit.convert(peakWeight);

    String formattedWeight;
    switch (unit) {
      case WeightUnit.grams:
        formattedWeight = displayWeight.toStringAsFixed(0);
        break;
      case WeightUnit.kilograms:
        formattedWeight = displayWeight.toStringAsFixed(2);
        break;
      case WeightUnit.pounds:
        formattedWeight = displayWeight.toStringAsFixed(1);
        break;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Unit selector row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'CURRENT WEIGHT',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Colors.grey,
                        letterSpacing: 1.2,
                      ),
                ),
                DropdownButton<WeightUnit>(
                  value: unit,
                  underline: const SizedBox(),
                  items: WeightUnit.values.map((u) {
                    return DropdownMenuItem(
                      value: u,
                      child: Text(u.symbol),
                    );
                  }).toList(),
                  onChanged: (u) {
                    if (u != null) onUnitChange(u);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Weight display
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  formattedWeight,
                  style: const TextStyle(
                    fontSize: 72,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  unit.symbol,
                  style: TextStyle(
                    fontSize: 24,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Peak weight
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Peak: ',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                Text(
                  '${displayPeak.toStringAsFixed(unit == WeightUnit.grams ? 0 : unit == WeightUnit.kilograms ? 2 : 1)} ${unit.symbol}',
                  style: const TextStyle(
                    color: Color(0xFF3B82F6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onResetPeak,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    minimumSize: Size.zero,
                  ),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onTare,
                  icon: const Icon(Icons.restart_alt),
                  label: const Text('Tare'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

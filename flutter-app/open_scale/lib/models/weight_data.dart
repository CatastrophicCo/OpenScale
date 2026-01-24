/// Weight data point for recording and graphing
class WeightDataPoint {
  final DateTime timestamp;
  final double weight; // in grams

  WeightDataPoint({
    required this.timestamp,
    required this.weight,
  });

  /// Get time in seconds from a reference point
  double getSecondsFrom(DateTime reference) {
    return timestamp.difference(reference).inMilliseconds / 1000.0;
  }
}

/// Unit conversion utilities
enum WeightUnit {
  grams('g'),
  kilograms('kg'),
  pounds('lbs');

  final String symbol;
  const WeightUnit(this.symbol);

  /// Convert weight from grams to this unit
  double convert(double grams) {
    switch (this) {
      case WeightUnit.grams:
        return grams;
      case WeightUnit.kilograms:
        return grams / 1000.0;
      case WeightUnit.pounds:
        return grams / 453.592;
    }
  }

  /// Format weight with appropriate decimal places
  String format(double grams) {
    final value = convert(grams);
    switch (this) {
      case WeightUnit.grams:
        return '${value.toStringAsFixed(0)} $symbol';
      case WeightUnit.kilograms:
        return '${value.toStringAsFixed(2)} $symbol';
      case WeightUnit.pounds:
        return '${value.toStringAsFixed(1)} $symbol';
    }
  }
}

/// Training session data
class TrainingSession {
  final String id;
  final DateTime date;
  final Duration duration;
  final double peakWeight;
  final double averageWeight;
  final List<WeightDataPoint> dataPoints;

  TrainingSession({
    required this.id,
    required this.date,
    required this.duration,
    required this.peakWeight,
    required this.averageWeight,
    required this.dataPoints,
  });
}

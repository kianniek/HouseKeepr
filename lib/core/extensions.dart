// Centralized UI formatting extensions used across the app.
// Move small display-only helpers here to avoid duplication.

const String kCurrencySymbol = '€';

extension StringFormatting on String {
  /// Converts strings like `some_value` or `SomeValue` to `Some Value`.
  String toTitleCase() {
    if (isEmpty) return this;
    return split(RegExp(r'[_\s]+'))
        .where((word) => word.isNotEmpty)
        .map(
          (word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  /// Capitalizes the first character of the string.
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  /// Normalizes repeat unit strings like "daily"/"week"/"monthly".
  String normalizeRepeatUnit() {
    final raw = toLowerCase().trim();
    switch (raw) {
      case 'day':
      case 'daily':
        return 'day';
      case 'week':
      case 'weekly':
        return 'week';
      case 'month':
      case 'monthly':
        return 'month';
      default:
        return 'day';
    }
  }
}

extension NumberFormatting on num {
  String toTrimmedFixed([int fractionDigits = 2]) {
    final fixed = toStringAsFixed(fractionDigits);
    var result = fixed;
    if (result.contains('.')) {
      while (result.endsWith('0')) {
        result = result.substring(0, result.length - 1);
      }
      if (result.endsWith('.')) {
        result = result.substring(0, result.length - 1);
      }
    }
    return result;
  }

  String toCurrency({
    String symbol = '€',
    int fractionDigits = 2,
    bool trimTrailingZeros = false,
  }) {
    final amount = trimTrailingZeros
        ? toTrimmedFixed(fractionDigits)
        : toStringAsFixed(fractionDigits);
    return '$symbol$amount';
  }
}

extension DateTimeFormatting on DateTime {
  String toLocalIsoDate() {
    final local = toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

extension DurationFormatting on Duration {
  String toClockMmSs() {
    if (isNegative) return '00:00';
    final totalSeconds = inSeconds;
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

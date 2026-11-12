import 'package:flutter/material.dart';

// Centralized UI formatting extensions used across the app.
// Move small display-only helpers here to avoid duplication.

const String kCurrencySymbol = '€';

/// Countries/locales that traditionally use Fahrenheit.
const Set<String> _kFahrenheitCountries = {'US', 'BS', 'BZ', 'KY', 'PW'};

/// Returns true if the device / system preferences specify Fahrenheit.
/// Defaults to Celsius if not determinable.
bool isSystemFahrenheit([BuildContext? context]) {
  try {
    Locale? loc;
    if (context != null) {
      loc = Localizations.maybeLocaleOf(context);
    }
    loc ??= WidgetsBinding.instance.platformDispatcher.locale;
    final country = loc.countryCode?.toUpperCase();
    if (country != null && _kFahrenheitCountries.contains(country)) {
      return true;
    }
  } catch (_) {}
  return false;
}

/// Formats a Celsius temperature into the device's default temperature format,
/// defaulting to Celsius (°C) if device preferences are unavailable.
String formatTemperature(double celsius, [BuildContext? context]) {
  final useFahrenheit = isSystemFahrenheit(context);
  if (useFahrenheit) {
    final fahrenheit = (celsius * 9 / 5) + 32;
    return '${fahrenheit.round()}°F';
  }
  return '${celsius.round()}°C';
}

/// Formats a [TimeOfDay] according to the phone's time formatting settings.
/// If unavailable, defaults to 24-hour format (HH:mm) without AM/PM.
String formatTimeWithSystemDefault(TimeOfDay time, [BuildContext? context]) {
  if (context != null) {
    try {
      final mediaQuery = MediaQuery.maybeOf(context);
      final alwaysUse24Hour = mediaQuery?.alwaysUse24HourFormat;
      if (alwaysUse24Hour != null) {
        if (alwaysUse24Hour) {
          final hour = time.hour.toString().padLeft(2, '0');
          final minute = time.minute.toString().padLeft(2, '0');
          return '$hour:$minute';
        } else {
          return time.format(context);
        }
      }

      final localizations = Localizations.of<MaterialLocalizations>(
        context,
        MaterialLocalizations,
      );
      if (localizations != null) {
        return localizations.formatTimeOfDay(time);
      }
    } catch (_) {}
  }

  try {
    final alwaysUse24Hour =
        WidgetsBinding.instance.platformDispatcher.alwaysUse24HourFormat;
    if (alwaysUse24Hour) {
      final hour = time.hour.toString().padLeft(2, '0');
      final minute = time.minute.toString().padLeft(2, '0');
      return '$hour:$minute';
    }
  } catch (_) {}

  // Fallback: 24-hour format without AM/PM
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

/// Formats a [DateTime] time portion according to phone's time settings.
/// Defaults to 24-hour format (HH:mm) without AM/PM if not available.
String formatDateTimeTimeToSystemDefault(
  DateTime dateTime, [
  BuildContext? context,
]) {
  final local = dateTime.toLocal();
  final timeOfDay = TimeOfDay(hour: local.hour, minute: local.minute);
  return formatTimeWithSystemDefault(timeOfDay, context);
}

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

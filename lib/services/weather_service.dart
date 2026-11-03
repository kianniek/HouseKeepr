import 'dart:convert';

import 'package:http/http.dart' as http;

class WeatherLocation {
  final String name;
  final String? country;
  final double latitude;
  final double longitude;

  const WeatherLocation({
    required this.name,
    required this.latitude,
    required this.longitude,
    this.country,
  });

  String get displayName =>
      country == null || country!.isEmpty ? name : '$name, $country';

  factory WeatherLocation.fromJson(Map<String, dynamic> json) {
    return WeatherLocation(
      name: (json['name'] as String?) ?? 'Unknown location',
      country: json['country'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final int weatherCode;

  const HourlyForecast({
    required this.time,
    required this.temperature,
    required this.weatherCode,
  });
}

class WeatherForecast {
  final double currentTemperature;
  final int currentWeatherCode;
  final List<HourlyForecast> hourly;

  const WeatherForecast({
    required this.currentTemperature,
    required this.currentWeatherCode,
    required this.hourly,
  });
}

class WeatherCondition {
  final String label;
  final String icon;

  const WeatherCondition(this.label, this.icon);

  static WeatherCondition fromCode(int code) {
    if (code == 0) return const WeatherCondition('Clear sky', '☀️');
    if (code == 1 || code == 2) {
      return const WeatherCondition('Partly cloudy', '🌤️');
    }
    if (code == 3) return const WeatherCondition('Overcast', '☁️');
    if (code >= 45 && code <= 48) {
      return const WeatherCondition('Foggy', '🌫️');
    }
    if (code >= 51 && code <= 57) {
      return const WeatherCondition('Drizzle', '🌦️');
    }
    if (code >= 61 && code <= 67) {
      return const WeatherCondition('Rain', '🌧️');
    }
    if (code >= 71 && code <= 77) {
      return const WeatherCondition('Snow', '🌨️');
    }
    if (code >= 80 && code <= 82) {
      return const WeatherCondition('Rain showers', '🌦️');
    }
    if (code >= 85 && code <= 86) {
      return const WeatherCondition('Snow showers', '🌨️');
    }
    if (code >= 95 && code <= 99) {
      return const WeatherCondition('Thunderstorm', '⛈️');
    }
    return const WeatherCondition('Unknown conditions', '🌡️');
  }
}

class WeatherApiException implements Exception {
  final String message;

  const WeatherApiException(this.message);

  @override
  String toString() => message;
}

class WeatherService {
  final http.Client _client;

  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<WeatherLocation>> searchLocations(String query) async {
    final trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return [];

    final response = await _client.get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': trimmedQuery,
        'count': '5',
      }),
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = json['results'] as List<dynamic>? ?? [];
    return results
        .whereType<Map<String, dynamic>>()
        .map(WeatherLocation.fromJson)
        .toList();
  }

  Future<WeatherForecast> fetchForecast(WeatherLocation location) async {
    final response = await _client.get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': location.latitude.toString(),
        'longitude': location.longitude.toString(),
        'current': 'temperature_2m,weather_code',
        'hourly': 'temperature_2m,weather_code',
        'timezone': 'auto',
      }),
    );
    _checkResponse(response);
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>;
    final hourly = json['hourly'] as Map<String, dynamic>;
    final times = hourly['time'] as List<dynamic>;
    final temperatures = hourly['temperature_2m'] as List<dynamic>;
    final codes = hourly['weather_code'] as List<dynamic>;

    return WeatherForecast(
      currentTemperature: (current['temperature_2m'] as num).toDouble(),
      currentWeatherCode: (current['weather_code'] as num).toInt(),
      hourly: [
        for (var index = 0; index < times.length; index++)
          HourlyForecast(
            time: DateTime.parse(times[index] as String),
            temperature: (temperatures[index] as num).toDouble(),
            weatherCode: (codes[index] as num).toInt(),
          ),
      ],
    );
  }

  void dispose() => _client.close();

  void _checkResponse(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw WeatherApiException(
        'Weather service returned status ${response.statusCode}.',
      );
    }
  }
}

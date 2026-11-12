import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/weather_service.dart';
import 'package:housekeepr/ui/features/dashboard/widgets/weather_card.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('searchLocations uses the Open-Meteo geocoding query', () async {
    Uri? requestedUri;
    final service = WeatherService(
      client: MockClient((request) async {
        requestedUri = request.url;
        return http.Response(
          jsonEncode({
            'results': [
              {
                'name': 'Utrecht',
                'country': 'Netherlands',
                'latitude': 52.09,
                'longitude': 5.12,
              },
            ],
          }),
          200,
        );
      }),
    );

    final results = await service.searchLocations('Utrecht');

    expect(requestedUri?.host, 'geocoding-api.open-meteo.com');
    expect(requestedUri?.queryParameters['name'], 'Utrecht');
    expect(requestedUri?.queryParameters['count'], '5');
    expect(results.single.displayName, 'Utrecht, Netherlands');
    service.dispose();
  });

  test('fetchForecast parses current and hourly data', () async {
    final service = WeatherService(
      client: MockClient((request) async {
        return http.Response(
          jsonEncode({
            'current': {'temperature_2m': 12.5, 'weather_code': 2},
            'hourly': {
              'time': ['2026-11-03T19:00', '2026-11-03T20:00'],
              'temperature_2m': [11.0, 10.5],
              'weather_code': [3, 61],
            },
          }),
          200,
        );
      }),
    );

    final forecast = await service.fetchForecast(
      const WeatherLocation(name: 'Test', latitude: 1, longitude: 2),
    );

    expect(forecast.currentTemperature, 12.5);
    expect(forecast.currentWeatherCode, 2);
    expect(forecast.hourly[1].temperature, 10.5);
    expect(forecast.hourly[1].weatherCode, 61);
    service.dispose();
  });

  test('findUpcomingForecast returns the first target within 24 hours', () {
    final now = DateTime(2026, 11, 3, 14);
    final hourly = [
      HourlyForecast(
        time: DateTime(2026, 11, 3, 19),
        temperature: 9,
        weatherCode: 61,
      ),
    ];

    final result = findUpcomingForecast(now, const [
      TimeOfDay(hour: 8, minute: 0),
      TimeOfDay(hour: 19, minute: 0),
    ], hourly);

    expect(result?.time, const TimeOfDay(hour: 19, minute: 0));
    expect(result?.forecast.temperature, 9);
  });

  test(
    'findUpcomingForecasts returns up to three upcoming targets in order',
    () {
      final now = DateTime(2026, 11, 3, 7);
      final hourly = [
        for (final hour in [8, 13, 19])
          HourlyForecast(
            time: DateTime(2026, 11, 3, hour),
            temperature: hour.toDouble(),
            weatherCode: 0,
          ),
      ];

      final results = findUpcomingForecasts(now, const [
        TimeOfDay(hour: 19, minute: 0),
        TimeOfDay(hour: 8, minute: 0),
        TimeOfDay(hour: 13, minute: 0),
        TimeOfDay(hour: 22, minute: 0),
      ], hourly);

      expect(results, hasLength(3));
      expect(results.map((result) => result.time.hour), [8, 13, 19]);
    },
  );

  test('forecastsForDisplay toggles between one and multiple forecasts', () {
    final forecasts = [
      for (var hour = 8; hour <= 18; hour += 5)
        ScheduledForecast(
          time: TimeOfDay(hour: hour, minute: 0),
          forecast: HourlyForecast(
            time: DateTime(2026, 11, 3, hour),
            temperature: hour.toDouble(),
            weatherCode: 0,
          ),
        ),
    ];

    expect(forecastsForDisplay(forecasts, showMultiple: false), hasLength(1));
    expect(forecastsForDisplay(forecasts, showMultiple: true), hasLength(3));
  });

  test('weather codes have readable conditions and icons', () {
    expect(WeatherCondition.fromCode(0).label, 'Clear sky');
    expect(WeatherCondition.fromCode(95).icon, '⛈️');
  });
}

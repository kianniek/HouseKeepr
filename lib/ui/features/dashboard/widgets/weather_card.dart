import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../../../core/extensions.dart';
import '../../../../../services/weather_service.dart';

class ScheduledForecast {
  final TimeOfDay time;
  final HourlyForecast forecast;

  const ScheduledForecast({required this.time, required this.forecast});
}

List<ScheduledForecast> findUpcomingForecasts(
  DateTime now,
  List<TimeOfDay> targetTimes,
  List<HourlyForecast> hourly,
) {
  final candidates = targetTimes.map((time) {
    var target = DateTime(now.year, now.month, now.day, time.hour, time.minute);
    if (!target.isAfter(now)) {
      target = target.add(const Duration(days: 1));
    }
    return (time: time, target: target);
  }).toList()..sort((a, b) => a.target.compareTo(b.target));

  final upcoming = <ScheduledForecast>[];
  for (final candidate in candidates) {
    if (candidate.target.isAfter(now.add(const Duration(hours: 24)))) {
      break;
    }
    final forecast = hourly.cast<HourlyForecast?>().firstWhere(
      (entry) =>
          entry!.time.year == candidate.target.year &&
          entry.time.month == candidate.target.month &&
          entry.time.day == candidate.target.day &&
          entry.time.hour == candidate.target.hour,
      orElse: () => null,
    );
    if (forecast != null) {
      upcoming.add(ScheduledForecast(time: candidate.time, forecast: forecast));
    }
    if (upcoming.length == 3) break;
  }
  return upcoming;
}

ScheduledForecast? findUpcomingForecast(
  DateTime now,
  List<TimeOfDay> targetTimes,
  List<HourlyForecast> hourly,
) {
  final upcoming = findUpcomingForecasts(now, targetTimes, hourly);
  return upcoming.isEmpty ? null : upcoming.first;
}

List<ScheduledForecast> forecastsForDisplay(
  List<ScheduledForecast> upcoming, {
  required bool showMultiple,
}) {
  return showMultiple ? upcoming : upcoming.take(1).toList();
}

class WeatherCard extends StatefulWidget {
  final WeatherService? weatherService;

  const WeatherCard({super.key, this.weatherService});

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> {
  late final WeatherService _weatherService;
  WeatherLocation _location = const WeatherLocation(
    name: 'Amsterdam',
    country: 'Netherlands',
    latitude: 52.3676,
    longitude: 4.9041,
  );
  List<TimeOfDay> _targetTimes = const [
    TimeOfDay(hour: 8, minute: 0),
    TimeOfDay(hour: 13, minute: 0),
    TimeOfDay(hour: 19, minute: 0),
  ];
  WeatherForecast? _forecast;
  Object? _error;
  bool _loading = true;
  bool _showMultipleForecasts = true;

  @override
  void initState() {
    super.initState();
    _weatherService = widget.weatherService ?? WeatherService();
    _loadForecast();
  }

  @override
  void dispose() {
    if (widget.weatherService == null) _weatherService.dispose();
    super.dispose();
  }

  Future<void> _loadForecast() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final forecast = await _weatherService.fetchForecast(_location);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final selection = await showModalBottomSheet<WeatherSelection>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LocationPickerSheet(
        weatherService: _weatherService,
        initialLocation: _location,
        initialTimes: _targetTimes,
        initialShowMultipleForecasts: _showMultipleForecasts,
      ),
    );
    if (!mounted || selection == null) return;
    setState(() {
      _location = selection.location;
      _targetTimes = selection.targetTimes;
      _showMultipleForecasts = selection.showMultipleForecasts;
    });
    await _loadForecast();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final condition = _forecast == null
        ? null
        : WeatherCondition.fromCode(_forecast!.currentWeatherCode);
    final upcoming = _forecast == null
        ? const <ScheduledForecast>[]
        : forecastsForDisplay(
            findUpcomingForecasts(
              DateTime.now(),
              _targetTimes,
              _forecast!.hourly,
            ),
            showMultiple: _showMultipleForecasts,
          );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openLocationPicker,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          constraints: const BoxConstraints(minHeight: 180),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _ErrorContent(onRetry: _loadForecast)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Weather',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          condition?.icon ?? '🌡️',
                          style: const TextStyle(fontSize: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      formatTemperature(_forecast!.currentTemperature, context),
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      _location.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      condition!.label,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    if (upcoming.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _UpcomingForecastCard(upcoming: upcoming),
                    ],
                  ],
                ),
        ),
      ),
    );
  }
}

class _ErrorContent extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorContent({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load weather'),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _UpcomingForecastCard extends StatelessWidget {
  final List<ScheduledForecast> upcoming;

  const _UpcomingForecastCard({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          for (var index = 0; index < upcoming.length; index++) ...[
            if (index > 0)
              Divider(
                height: 1,
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            _UpcomingForecastRow(forecast: upcoming[index]),
          ],
        ],
      ),
    );
  }
}

class _UpcomingForecastRow extends StatelessWidget {
  final ScheduledForecast forecast;

  const _UpcomingForecastRow({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final condition = WeatherCondition.fromCode(forecast.forecast.weatherCode);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 12, color: scheme.onSurfaceVariant),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              formatTimeWithSystemDefault(forecast.time, context),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11),
            ),
          ),
          const SizedBox(width: 4),
          Text(condition.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 3),
          Text(
            formatTemperature(forecast.forecast.temperature, context),
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class WeatherSelection {
  final WeatherLocation location;
  final List<TimeOfDay> targetTimes;
  final bool showMultipleForecasts;

  const WeatherSelection({
    required this.location,
    required this.targetTimes,
    required this.showMultipleForecasts,
  });
}

class _LocationPickerSheet extends StatefulWidget {
  final WeatherService weatherService;
  final WeatherLocation initialLocation;
  final List<TimeOfDay> initialTimes;
  final bool initialShowMultipleForecasts;

  const _LocationPickerSheet({
    required this.weatherService,
    required this.initialLocation,
    required this.initialTimes,
    required this.initialShowMultipleForecasts,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  late final TextEditingController _searchController;
  Timer? _debounce;
  List<WeatherLocation> _suggestions = [];
  late WeatherLocation _location;
  late List<TimeOfDay> _times;
  late bool _showMultipleForecasts;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _location = widget.initialLocation;
    _times = [...widget.initialTimes];
    _showMultipleForecasts = widget.initialShowMultipleForecasts;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _search(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () async {
      setState(() {
        _searching = true;
        _error = null;
      });
      try {
        final suggestions = await widget.weatherService.searchLocations(query);
        if (!mounted) return;
        setState(() {
          _suggestions = suggestions;
          _searching = false;
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _searching = false;
          _error = error.toString();
        });
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    setState(() => _error = null);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw const LocationServiceDisabledException();
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        throw const PermissionDeniedException(
          'Location permission was denied.',
        );
      }
      if (permission == LocationPermission.deniedForever) {
        throw const PermissionDeniedException(
          'Location permission is permanently denied. Enable it in system settings.',
        );
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _location = WeatherLocation(
          name: 'Current location',
          latitude: position.latitude,
          longitude: position.longitude,
        );
        _searchController.clear();
        _suggestions = [];
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _locationError(error));
    }
  }

  String _locationError(Object error) {
    if (error is LocationServiceDisabledException) {
      return 'Location services are disabled. Enable them and try again.';
    }
    if (error is PermissionDeniedException) {
      return error.message ?? 'Location permission was denied.';
    }
    return 'Could not determine your current location.';
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked == null || !mounted) return;
    if (_times.any(
      (time) => time.hour == picked.hour && time.minute == picked.minute,
    )) {
      return;
    }
    setState(() => _times = [..._times, picked]..sort(_compareTimes));
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) =>
      (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute);

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPadding + 20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 650),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Weather location',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  onChanged: _search,
                  decoration: const InputDecoration(
                    labelText: 'Search for a city',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                  ),
                ),
                if (_searching)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: LinearProgressIndicator(),
                  ),
                ..._suggestions.map(
                  (location) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_city),
                    title: Text(location.displayName),
                    onTap: () => setState(() {
                      _location = location;
                      _searchController.text = location.displayName;
                      _suggestions = [];
                    }),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _useCurrentLocation,
                  icon: const Icon(Icons.my_location),
                  label: const Text('Use Current Location'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Forecast times',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Show multiple upcoming times'),
                  subtitle: const Text(
                    'Display up to three forecasts on the card',
                  ),
                  value: _showMultipleForecasts,
                  onChanged: (value) =>
                      setState(() => _showMultipleForecasts = value),
                ),
                const SizedBox(height: 4),
                if (_times.isEmpty)
                  const Text('No target times selected.')
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _times
                        .map(
                          (time) => InputChip(
                            label: Text(
                              formatTimeWithSystemDefault(time, context),
                            ),
                            selected: true,
                            onSelected: (_) => setState(
                              () => _times = _times
                                  .where(
                                    (item) =>
                                        item.hour != time.hour ||
                                        item.minute != time.minute,
                                  )
                                  .toList(),
                            ),
                            onDeleted: () => setState(
                              () => _times = _times
                                  .where(
                                    (item) =>
                                        item.hour != time.hour ||
                                        item.minute != time.minute,
                                  )
                                  .toList(),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                TextButton.icon(
                  onPressed: _addTime,
                  icon: const Icon(Icons.add),
                  label: const Text('Add time'),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.pop(
                      context,
                      WeatherSelection(
                        location: _location,
                        targetTimes: _times,
                        showMultipleForecasts: _showMultipleForecasts,
                      ),
                    ),
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

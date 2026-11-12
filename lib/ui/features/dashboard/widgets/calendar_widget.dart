import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../../core/extensions.dart';
import 'package:googleapis/calendar/v3.dart' as calendar;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../../services/calendar_service.dart';

class CalendarWidget extends StatefulWidget {
  final CalendarService? calendarService;

  const CalendarWidget({super.key, this.calendarService});

  @override
  State<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends State<CalendarWidget> {
  late final CalendarService _calendarService;
  calendar.CalendarListEntry? _selectedCalendar;
  calendar.Event? _nextEvent;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _calendarService = widget.calendarService ?? CalendarService();
    _loadEvent();
  }

  Future<void> _loadEvent() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final calendars = await _calendarService.listCalendars();
      if (calendars.isEmpty) {
        throw StateError('No Google Calendars are available.');
      }
      final selectedId = await _calendarService.selectedCalendarId();
      final selected = calendars.firstWhere(
        (entry) => entry.id == selectedId,
        orElse: () => calendars.first,
      );
      if (selected.id == null) {
        throw StateError('The selected Google Calendar has no id.');
      }
      final events = await _calendarService.upcomingEvents(selected.id!);
      if (!mounted) return;
      setState(() {
        _selectedCalendar = selected;
        _nextEvent = events.isEmpty ? null : events.first;
        _loading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Calendar load error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
      _showDebugToast(error);
    }
  }

  void _showDebugToast(Object error) {
    if (!kDebugMode || !mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('Calendar Error: $error'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }

  Future<void> _openCalendarPicker() async {
    try {
      final calendars = await _calendarService.listCalendars();
      if (!mounted) return;
      final selected = await showModalBottomSheet<calendar.CalendarListEntry>(
        context: context,
        isScrollControlled: true,
        builder: (_) => _CalendarPickerSheet(
          calendarService: _calendarService,
          calendars: calendars,
          selectedId: _selectedCalendar?.id,
          onRefresh: _loadEvent,
        ),
      );
      if (!mounted || selected?.id == null) return;
      await _calendarService.selectCalendar(selected!.id!);
      await _loadEvent();
    } catch (error, stackTrace) {
      debugPrint('Calendar picker error: $error\n$stackTrace');
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
      _showDebugToast(error);
    }
  }

  Future<void> _openEvent() async {
    final link = _nextEvent?.htmlLink;
    final uri = Uri.tryParse(link ?? 'https://calendar.google.com/');
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      final fallback = Uri.parse('https://calendar.google.com/');
      if (!await launchUrl(fallback, mode: LaunchMode.externalApplication) &&
          mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open Google Calendar.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _openCalendarPicker,
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
              ? _ErrorContent(onRetry: _loadEvent, error: _error)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Next Event',
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Icon(
                                Icons.calendar_today_rounded,
                                color: scheme.primary,
                                size: 20,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_nextEvent == null)
                            Text(
                              'No upcoming events',
                              style: textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            )
                          else ...[
                            Text(
                              _nextEvent!.summary ?? 'Untitled event',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatEventStart(_nextEvent!),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            if ((_nextEvent!.location ??
                                    _nextEvent!.hangoutLink) !=
                                null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _nextEvent!.location ?? 'Google Meet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _selectedCalendar?.summary ?? 'Google Calendar',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        if (_nextEvent != null)
                          IconButton(
                            tooltip: 'Go to Calendar',
                            onPressed: _openEvent,
                            icon: const Icon(Icons.open_in_new),
                            color: scheme.primary,
                            visualDensity: VisualDensity.compact,
                          ),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  String _formatEventStart(calendar.Event event) {
    final start = event.start;
    final dateTime = start?.dateTime;
    if (dateTime != null) {
      final now = DateTime.now();
      final day =
          dateTime.year == now.year &&
          dateTime.month == now.month &&
          dateTime.day == now.day;
      final timeStr = formatDateTimeTimeToSystemDefault(dateTime, context);
      return day
          ? 'Today at $timeStr'
          : '${DateFormat('EEE, d MMM').format(dateTime.toLocal())} at $timeStr';
    }
    final date = start?.date;
    return date == null
        ? 'All-day event'
        : DateFormat('EEE, d MMM').format(date);
  }
}

class _CalendarPickerSheet extends StatefulWidget {
  final CalendarService calendarService;
  final List<calendar.CalendarListEntry> calendars;
  final String? selectedId;
  final Future<void> Function() onRefresh;

  const _CalendarPickerSheet({
    required this.calendarService,
    required this.calendars,
    required this.selectedId,
    required this.onRefresh,
  });

  @override
  State<_CalendarPickerSheet> createState() => _CalendarPickerSheetState();
}

class _CalendarPickerSheetState extends State<_CalendarPickerSheet> {
  late List<calendar.CalendarListEntry> _calendars = widget.calendars;
  bool _refreshing = false;

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final calendars = await widget.calendarService.listCalendars();
      if (mounted) setState(() => _calendars = calendars);
      await widget.onRefresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh calendars: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            title: const Text('Choose calendar'),
            trailing: IconButton(
              tooltip: 'Refresh calendars',
              onPressed: _refreshing ? null : _refresh,
              icon: _refreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _calendars.length,
              itemBuilder: (context, index) {
                final entry = _calendars[index];
                return ListTile(
                  leading: CircleAvatar(
                    radius: 8,
                    backgroundColor: _parseColor(entry.backgroundColor),
                  ),
                  title: Text(entry.summary ?? entry.id ?? 'Calendar'),
                  trailing: entry.id == widget.selectedId
                      ? const Icon(Icons.check)
                      : null,
                  onTap: entry.id == null
                      ? null
                      : () => Navigator.of(context).pop(entry),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String? value) {
    if (value == null) return Theme.of(context).colorScheme.primary;
    final hex = value.replaceFirst('#', '');
    final sixDigit = hex.length == 6 ? 'FF$hex' : hex;
    final color = int.tryParse(sixDigit, radix: 16);
    return color == null ? Theme.of(context).colorScheme.primary : Color(color);
  }
}

class _ErrorContent extends StatelessWidget {
  final VoidCallback onRetry;
  final Object? error;

  const _ErrorContent({required this.onRetry, this.error});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Unable to load Google Calendar'),
          if (kDebugMode && error != null) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '$error',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:housekeepr/models/medication.dart';
import 'package:housekeepr/repositories/local_medication_repository.dart';
import 'package:housekeepr/services/notification_service.dart';
import 'package:housekeepr/services/widget_service.dart';
import 'package:housekeepr/ui/common/widgets/empty_state.dart';
import 'package:housekeepr/ui/features/profile/pages/widget_settings_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MedicationRemindersPage extends StatefulWidget {
  final LocalMedicationRepository? repository;

  const MedicationRemindersPage({super.key, this.repository});

  @override
  State<MedicationRemindersPage> createState() =>
      _MedicationRemindersPageState();
}

class _MedicationRemindersPageState extends State<MedicationRemindersPage>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final LocalMedicationRepository _repository;
  late final TabController _tabController;

  bool _isLoading = true;
  List<Medication> _medications = [];
  WidgetDoseSummary? _todaySummary;
  final DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalMedicationRepository();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.medicationUpdatesNotifier.addListener(
      _onMedicationNotificationUpdate,
    );
    _loadData();
  }

  @override
  void dispose() {
    NotificationService.instance.medicationUpdatesNotifier.removeListener(
      _onMedicationNotificationUpdate,
    );
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _reloadFromDiskAndRefresh();
    }
  }

  void _onMedicationNotificationUpdate() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _reloadFromDiskAndRefresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
    } catch (_) {}
    if (mounted) {
      await _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final meds = await _repository.getMedications();
      final summary = await _repository.getWidgetSummary(_selectedDate);
      if (mounted) {
        setState(() {
          _medications = meds;
          _todaySummary = summary;
          _isLoading = false;
        });
      }
      // Update widget data
      await _syncWidget();
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading medications: $e')),
        );
      }
    }
  }

  Future<void> _syncWidget() async {
    try {
      final summary = await _repository.getWidgetSummary(DateTime.now());
      await WidgetService.instance.updateMedicationWidget(summary);
    } catch (_) {
      // Ignore widget bridge errors in tests/non-supported environments
    }
  }

  Future<void> _onToggleSlot(TimeOfDaySlot slot, bool currentValue) async {
    final newStatus = currentValue ? DoseStatus.pending : DoseStatus.taken;
    await _repository.setSlotDosesStatus(
      date: _selectedDate,
      slot: slot,
      status: newStatus,
    );
    await _loadData();
  }

  Future<void> _onToggleDose(DoseInstance dose) async {
    await _repository.toggleDoseStatus(dose);
    await _loadData();
  }

  Future<void> _onSetDoseStatus(DoseInstance dose, DoseStatus status) async {
    await _repository.recordDoseStatus(
      doseId: dose.id,
      medicationId: dose.medicationId,
      dateKey: Medication.dateToKey(_selectedDate),
      status: status,
    );
    await _loadData();
  }

  Future<void> _openMedicationForm([Medication? existing]) async {
    final result = await showModalBottomSheet<Medication>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _MedicationFormSheet(medication: existing),
    );

    if (result != null) {
      await _repository.saveMedication(result);
      if (result.isActive) {
        await NotificationService.instance.scheduleMedicationReminders(result);
      } else {
        await NotificationService.instance.cancelMedicationReminders(result.id);
      }
      await _loadData();
    }
  }

  Future<void> _onToggleMedicationActive(Medication med, bool isActive) async {
    await _repository.setMedicationActive(med.id, isActive);
    final updated = med.copyWith(isActive: isActive);
    if (isActive) {
      await NotificationService.instance.scheduleMedicationReminders(updated);
    } else {
      await NotificationService.instance.cancelMedicationReminders(med.id);
    }
    await _loadData();
  }

  Future<void> _onDeleteMedication(Medication med) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Medication?'),
        content: Text(
          'Are you sure you want to delete "${med.name}"? This will cancel all upcoming reminders.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _repository.deleteMedication(med.id);
      await NotificationService.instance.cancelMedicationReminders(med.id);
      await _loadData();
    }
  }

  DoseInstance? _getNextScheduledDose() {
    final summary = _todaySummary;
    if (summary != null) {
      final now = DateTime.now();
      final currentMinutes = now.hour * 60 + now.minute;

      final upcomingToday = summary.allDoses.where((d) {
        final doseMinutes = d.time.hour * 60 + d.time.minute;
        return d.isPending && doseMinutes >= currentMinutes;
      }).toList();

      if (upcomingToday.isNotEmpty) {
        return upcomingToday.first;
      }

      final pendingToday = summary.allDoses.where((d) => d.isPending).toList();
      if (pendingToday.isNotEmpty) {
        return pendingToday.first;
      }
    }

    final activeMeds = _medications
        .where((m) => m.isActive && m.notificationTimes.isNotEmpty)
        .toList();
    if (activeMeds.isNotEmpty) {
      final firstMed = activeMeds.first;
      return DoseInstance(
        id: 'preview',
        medicationId: firstMed.id,
        medicationName: firstMed.name,
        dosage: firstMed.dosage,
        scheduledDate: DateTime.now(),
        time: firstMed.notificationTimes.first,
        slot: firstMed.notificationTimes.first.slot,
      );
    }

    return null;
  }

  void _showWidgetHelp() {
    final nextDose = _getNextScheduledDose();
    final nextMedName = nextDose?.medicationName ?? 'Vitamin D';
    final nextDosage = nextDose?.dosage ?? '1000 IU';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.widgets_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Widget & Notifications',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'You can track your daily pills directly from your home screen with a 2x2 widget:\n\n'
              '• ☀️ Daytime slot: Check off morning/afternoon doses\n'
              '• 🌙 Evening slot: Check off evening/night doses\n'
              '• Tap the card header anytime to open this page.',
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: const Text('Widget Settings'),
              subtitle: const Text(
                'Hide unused toggles, customize title & dose counts',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const PillWidgetSettingsPage(),
                  ),
                );
              },
            ),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: Theme.of(context).colorScheme.primary,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'Medication Reminder Preview',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Next scheduled: $nextMedName'
              '${nextDosage.isNotEmpty ? ' ($nextDosage)' : ''}.\n'
              'Includes a "Remind me later" action that reschedules the reminder for 1 hour later.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh),
                    label: const Text('Sync Widget'),
                    onPressed: () {
                      Navigator.pop(ctx);
                      _syncWidget();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Widget refreshed!')),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Test Notification'),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      await NotificationService.instance
                          .showTestMedicationNotification(
                            medicationName: nextMedName,
                            dosage: nextDosage,
                            medicationId: nextDose?.medicationId,
                            doseId: nextDose?.id,
                            dateKey: nextDose == null
                                ? null
                                : Medication.dateToKey(nextDose.scheduledDate),
                          );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Test notification sent for $nextMedName'
                              '${nextDosage.isNotEmpty ? ' ($nextDosage)' : ''}',
                            ),
                          ),
                        );
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medication Reminders'),
        actions: [
          IconButton(
            icon: const Icon(Icons.widgets_outlined),
            tooltip: 'Home-Screen Widget',
            onPressed: _showWidgetHelp,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "Today's Schedule", icon: Icon(Icons.today)),
            Tab(text: 'Medications', icon: Icon(Icons.medication)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openMedicationForm(),
        icon: const Icon(Icons.add),
        label: const Text('Add Medication'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildScheduleTab(colorScheme),
                _buildMedicationsTab(colorScheme),
              ],
            ),
    );
  }

  Widget _buildScheduleTab(ColorScheme colorScheme) {
    final summary = _todaySummary;
    if (summary == null || summary.allDoses.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.check_circle_outline,
          message: 'No doses scheduled for today',
          subMessage: _medications.isEmpty
              ? 'Add your medications to start tracking reminders.'
              : 'All your medications are scheduled on other days.',
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        // Daytime Slot (Sun ☀️)
        _buildSlotCard(
          title: 'Daytime',
          icon: Icons.wb_sunny_rounded,
          iconColor: Colors.amber.shade700,
          doses: summary.morningDoses,
          isTaken: summary.isMorningTaken,
          onToggleSlot: () =>
              _onToggleSlot(TimeOfDaySlot.morning, summary.isMorningTaken),
          colorScheme: colorScheme,
        ),
        const SizedBox(height: 16),
        // Evening Slot (Moon 🌙)
        _buildSlotCard(
          title: 'Evening',
          icon: Icons.nightlight_round,
          iconColor: Colors.indigo.shade400,
          doses: summary.eveningDoses,
          isTaken: summary.isEveningTaken,
          onToggleSlot: () =>
              _onToggleSlot(TimeOfDaySlot.evening, summary.isEveningTaken),
          colorScheme: colorScheme,
        ),
      ],
    );
  }

  Widget _buildSlotCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<DoseInstance> doses,
    required bool isTaken,
    required VoidCallback onToggleSlot,
    required ColorScheme colorScheme,
  }) {
    if (doses.isEmpty) {
      return Card(
        elevation: 0,
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor.withValues(alpha: 0.4), size: 28),
              const SizedBox(width: 12),
              Text(
                '$title — No doses scheduled',
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isTaken
              ? colorScheme.primary.withValues(alpha: 0.4)
              : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        isTaken
                            ? 'All doses marked as taken'
                            : '${doses.where((d) => d.isTaken).length}/${doses.length} taken',
                        style: TextStyle(
                          fontSize: 12,
                          color: isTaken
                              ? colorScheme.primary
                              : colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick Toggle switch matching widget behavior
                Switch(value: isTaken, onChanged: (_) => onToggleSlot()),
              ],
            ),
            const Divider(height: 24),
            ...doses.map((dose) => _buildDoseRow(dose, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildDoseRow(DoseInstance dose, ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Checkbox(value: dose.isTaken, onChanged: (_) => _onToggleDose(dose)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dose.medicationName,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    decoration: dose.isTaken
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                Text(
                  '${dose.time.format24h()}${dose.dosage.isNotEmpty ? ' • ${dose.dosage}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (dose.isSkipped)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Skipped',
                style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.onErrorContainer,
                ),
              ),
            )
          else ...[
            IconButton(
              icon: Icon(Icons.block, size: 20, color: colorScheme.outline),
              tooltip: 'Skip dose',
              onPressed: () => _onSetDoseStatus(dose, DoseStatus.skipped),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationsTab(ColorScheme colorScheme) {
    if (_medications.isEmpty) {
      return Center(
        child: EmptyStateWidget(
          icon: Icons.medication_outlined,
          message: 'No medications added yet',
          subMessage: 'Tap the button below to add your first medication.',
        ),
      );
    }

    final activeMeds = _medications.where((m) => m.isActive).toList();
    final inactiveMeds = _medications.where((m) => !m.isActive).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
      children: [
        if (activeMeds.isNotEmpty) ...[
          Text(
            'ACTIVE MEDICATIONS (${activeMeds.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...activeMeds.map((m) => _buildMedicationCard(m, colorScheme)),
          const SizedBox(height: 24),
        ],
        if (inactiveMeds.isNotEmpty) ...[
          Text(
            'INACTIVE / PAUSED (${inactiveMeds.length})',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: colorScheme.outline,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 8),
          ...inactiveMeds.map((m) => _buildMedicationCard(m, colorScheme)),
        ],
      ],
    );
  }

  Widget _buildMedicationCard(Medication med, ColorScheme colorScheme) {
    final timesStr = med.notificationTimes.map((t) => t.format24h()).join(', ');
    String recurrenceStr;
    switch (med.recurrenceType) {
      case MedicationRecurrenceType.daily:
        recurrenceStr = 'Daily';
        break;
      case MedicationRecurrenceType.specificDaysOfWeek:
        final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        recurrenceStr = med.daysOfWeek.map((d) => days[d - 1]).join(', ');
        break;
      case MedicationRecurrenceType.intervalDays:
        recurrenceStr = 'Every ${med.intervalDays} days';
        break;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: med.isActive
          ? colorScheme.surfaceContainerLow
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        onTap: () => _openMedicationForm(med),
        leading: CircleAvatar(
          backgroundColor: med.isActive
              ? colorScheme.primaryContainer
              : colorScheme.surfaceContainerHighest,
          child: Icon(
            Icons.medication,
            color: med.isActive
                ? colorScheme.onPrimaryContainer
                : colorScheme.outline,
          ),
        ),
        title: Text(
          med.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: med.isActive ? null : colorScheme.outline,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (med.dosage.isNotEmpty)
              Text(
                med.dosage,
                style: TextStyle(
                  color: med.isActive
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.outline,
                ),
              ),
            Text(
              '$recurrenceStr • $timesStr',
              style: TextStyle(
                fontSize: 12,
                color: med.isActive ? colorScheme.primary : colorScheme.outline,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              value: med.isActive,
              onChanged: (val) => _onToggleMedicationActive(med, val),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: colorScheme.error,
              onPressed: () => _onDeleteMedication(med),
            ),
          ],
        ),
      ),
    );
  }
}

class _MedicationFormSheet extends StatefulWidget {
  final Medication? medication;

  const _MedicationFormSheet({this.medication});

  @override
  State<_MedicationFormSheet> createState() => _MedicationFormSheetState();
}

class _MedicationFormSheetState extends State<_MedicationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late MedicationRecurrenceType _recurrenceType;
  late List<int> _daysOfWeek;
  late int _intervalDays;
  late DateTime _startDate;
  DateTime? _endDate;
  late List<MedicationTime> _notificationTimes;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _nameController = TextEditingController(text: m?.name ?? '');
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _recurrenceType = m?.recurrenceType ?? MedicationRecurrenceType.daily;
    _daysOfWeek = List<int>.from(m?.daysOfWeek ?? [1, 2, 3, 4, 5, 6, 7]);
    _intervalDays = m?.intervalDays ?? 1;
    _startDate = m?.startDate ?? DateTime.now();
    _endDate = m?.endDate;
    _notificationTimes = List<MedicationTime>.from(
      m?.notificationTimes ?? [MedicationTime(hour: 8, minute: 0)],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  Future<void> _addNotificationTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (picked != null) {
      final newTime = MedicationTime(hour: picked.hour, minute: picked.minute);
      if (!_notificationTimes.any(
        (t) => t.hour == newTime.hour && t.minute == newTime.minute,
      )) {
        setState(() {
          _notificationTimes.add(newTime);
          _notificationTimes.sort((a, b) {
            final h = a.hour.compareTo(b.hour);
            return h != 0 ? h : a.minute.compareTo(b.minute);
          });
        });
      }
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    if (_notificationTimes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one notification time.'),
        ),
      );
      return;
    }

    final id =
        widget.medication?.id ?? 'med_${DateTime.now().millisecondsSinceEpoch}';
    final med = Medication(
      id: id,
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      isActive: widget.medication?.isActive ?? true,
      recurrenceType: _recurrenceType,
      daysOfWeek: _daysOfWeek,
      intervalDays: _intervalDays,
      startDate: _startDate,
      endDate: _endDate,
      notificationTimes: _notificationTimes,
      createdAt: widget.medication?.createdAt,
    );

    Navigator.pop(context, med);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.medication != null;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Medication' : 'Add Medication',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name *',
                  hintText: 'e.g. Vitamin D, Metformin',
                  prefixIcon: Icon(Icons.medication),
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val == null || val.trim().isEmpty
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _dosageController,
                decoration: const InputDecoration(
                  labelText: 'Dosage (optional)',
                  hintText: 'e.g. 1 pill, 500mg, 2 drops',
                  prefixIcon: Icon(Icons.fitness_center),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Schedule & Recurrence',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<MedicationRecurrenceType>(
                segments: const [
                  ButtonSegment(
                    value: MedicationRecurrenceType.daily,
                    label: Text('Daily'),
                  ),
                  ButtonSegment(
                    value: MedicationRecurrenceType.specificDaysOfWeek,
                    label: Text('Days of Week'),
                  ),
                  ButtonSegment(
                    value: MedicationRecurrenceType.intervalDays,
                    label: Text('Interval'),
                  ),
                ],
                selected: {_recurrenceType},
                onSelectionChanged: (set) {
                  setState(() => _recurrenceType = set.first);
                },
              ),
              const SizedBox(height: 12),
              if (_recurrenceType ==
                  MedicationRecurrenceType.specificDaysOfWeek) ...[
                Wrap(
                  spacing: 6,
                  children: List.generate(7, (i) {
                    final day = i + 1;
                    const labels = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                    final isSelected = _daysOfWeek.contains(day);
                    return FilterChip(
                      label: Text(labels[i]),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _daysOfWeek.add(day);
                            _daysOfWeek.sort();
                          } else if (_daysOfWeek.length > 1) {
                            _daysOfWeek.remove(day);
                          }
                        });
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
              ],
              if (_recurrenceType == MedicationRecurrenceType.intervalDays) ...[
                Row(
                  children: [
                    const Text('Every '),
                    SizedBox(
                      width: 60,
                      child: TextFormField(
                        initialValue: _intervalDays.toString(),
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          final parsed = int.tryParse(val);
                          if (parsed != null && parsed > 0) {
                            _intervalDays = parsed;
                          }
                        },
                      ),
                    ),
                    const Text(' days'),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 12),
              Text(
                'Notification Times',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ..._notificationTimes.map((time) {
                    final isMorning = time.slot == TimeOfDaySlot.morning;
                    return Chip(
                      avatar: Icon(
                        isMorning
                            ? Icons.wb_sunny_rounded
                            : Icons.nightlight_round,
                        size: 16,
                        color: isMorning
                            ? Colors.amber.shade700
                            : Colors.indigo.shade400,
                      ),
                      label: Text(time.format24h()),
                      onDeleted: _notificationTimes.length > 1
                          ? () {
                              setState(() {
                                _notificationTimes.remove(time);
                              });
                            }
                          : null,
                    );
                  }),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 16),
                    label: const Text('Add Time'),
                    onPressed: _addNotificationTime,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  TextButton.icon(
                    icon: const Icon(
                      Icons.notifications_active_outlined,
                      size: 18,
                    ),
                    label: const Text('Test'),
                    onPressed: () {
                      final name = _nameController.text.trim();
                      final dosage = _dosageController.text.trim();
                      NotificationService.instance
                          .showTestMedicationNotification(
                            medicationName: name.isNotEmpty
                                ? name
                                : 'Vitamin D',
                            dosage: dosage.isNotEmpty ? dosage : '1000 IU',
                          );
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Test notification sent')),
                      );
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _onSave,
                    child: Text(isEditing ? 'Save Changes' : 'Add Medication'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

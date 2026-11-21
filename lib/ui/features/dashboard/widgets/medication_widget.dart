import 'package:flutter/material.dart';

import '../../../../../models/medication.dart';
import '../../../../../repositories/local_medication_repository.dart';
import '../../../../../services/app_haptics.dart';
import '../../../../../services/notification_service.dart';
import '../../../../../services/widget_service.dart';
import '../../tools/pages/medication_reminders_page.dart';
import 'stable_loading_card.dart';

class MedicationWidget extends StatefulWidget {
  final LocalMedicationRepository? repository;

  const MedicationWidget({super.key, this.repository});

  @override
  State<MedicationWidget> createState() => _MedicationWidgetState();
}

class _MedicationWidgetState extends State<MedicationWidget>
    with WidgetsBindingObserver {
  late final LocalMedicationRepository _repository;
  WidgetDoseSummary? _summary;
  List<Medication> _medications = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? LocalMedicationRepository();
    WidgetsBinding.instance.addObserver(this);
    NotificationService.instance.medicationUpdatesNotifier.addListener(
      _onMedicationUpdate,
    );
    _loadData();
  }

  @override
  void dispose() {
    NotificationService.instance.medicationUpdatesNotifier.removeListener(
      _onMedicationUpdate,
    );
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  void _onMedicationUpdate() {
    if (mounted) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      final meds = await _repository.getMedications();
      final summary = await _repository.getWidgetSummary(DateTime.now());
      if (!mounted) return;
      setState(() {
        _medications = meds;
        _summary = summary;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  DoseInstance? _nextPendingDose(WidgetDoseSummary? summary) {
    if (summary == null) return null;
    for (final dose in summary.allDoses) {
      if (dose.isPending) return dose;
    }
    return null;
  }

  Future<void> _markTaken(DoseInstance dose) async {
    AppHaptics.instance.confirm();
    await _repository.recordDoseStatus(
      doseId: dose.id,
      medicationId: dose.medicationId,
      dateKey: Medication.dateToKey(dose.scheduledDate),
      status: DoseStatus.taken,
    );
    await _loadData();
    try {
      final summary = await _repository.getWidgetSummary(DateTime.now());
      await WidgetService.instance.updateMedicationWidget(summary);
    } catch (_) {
      // Ignore widget bridge errors in tests/non-supported environments
    }
  }

  Future<void> _openMedications() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MedicationRemindersPage(repository: _repository),
      ),
    );
    if (mounted) {
      await _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final summary = _summary;
    final activeMeds = _medications.where((m) => m.isActive).toList();
    final nextDose = _nextPendingDose(summary);
    final hasAnyDosesToday = summary != null && summary.allDoses.isNotEmpty;

    return StableLoadingCard(
      storageKey: 'dashboard_card_height_medications_v1',
      isLoading: _loading,
      onTap: _openMedications,
      child: _loading
          ? const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            )
          : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.medication_outlined,
                          size: 18,
                          color: scheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Medications',
                            style: textTheme.labelMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (activeMeds.isEmpty || !hasAnyDosesToday)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeMeds.isEmpty
                                ? 'No meds set up'
                                : 'None due today',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Tap to manage',
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (summary.hasMorningDoses)
                            _SlotPill(
                              icon: Icons.wb_sunny_outlined,
                              label: 'AM',
                              done: summary.isMorningTaken,
                            ),
                          if (summary.hasEveningDoses)
                            _SlotPill(
                              icon: Icons.nightlight_outlined,
                              label: 'PM',
                              done: summary.isEveningTaken,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (nextDose != null) ...[
                        Text(
                          nextDose.medicationName,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextDose.dosage.isNotEmpty
                              ? '${nextDose.time.format24h()} · ${nextDose.dosage}'
                              : nextDose.time.format24h(),
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.tonalIcon(
                            onPressed: () => _markTaken(nextDose),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              minimumSize: const Size(0, 32),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Mark Taken'),
                          ),
                        ),
                      ] else
                        Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 18,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'All doses taken',
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ],
                ),
    );
  }
}

class _SlotPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool done;

  const _SlotPill({
    required this.icon,
    required this.label,
    required this.done,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final bgColor = done
        ? scheme.primaryContainer
        : scheme.surfaceContainerHigh;
    final fgColor = done ? scheme.onPrimaryContainer : scheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(done ? Icons.check_circle : icon, size: 13, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: fgColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

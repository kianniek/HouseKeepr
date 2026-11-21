// ignore_for_file: use_build_context_synchronously

import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/core/extensions.dart';
import 'package:uuid/uuid.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../models/task.dart';
import '../../../../services/app_haptics.dart';
import '../../../../services/household_service.dart';
import '../../../common/widgets/keyboard_inset_padding.dart';
import '../utils/task_date_utils.dart';

class _TaskReminderPreset {
  final String title;
  final String room;
  final int interval;
  final String unit;
  const _TaskReminderPreset(this.title, this.room, this.interval, this.unit);
}

const List<_TaskReminderPreset> _reminderPresets = [
  _TaskReminderPreset('Dust ceiling corners', 'Living Room', 1, 'month'),
  _TaskReminderPreset('Refresh water filter', 'Kitchen', 1, 'month'),
  _TaskReminderPreset('Wash throw blankets', 'Living Room', 1, 'month'),
  _TaskReminderPreset('Wipe bathroom mirror', 'Bathroom', 1, 'week'),
  _TaskReminderPreset('Empty kitchen bin', 'Kitchen', 1, 'week'),
  _TaskReminderPreset('Flip mattress', 'Bedroom', 1, 'month'),
];

const List<String> _taskRoomOptions = [
  'Bathroom',
  'Kitchen',
  'Bedroom',
  'Living Room',
];

/// Shows the add/edit Task dialog and saves via TaskCubit.
Future<void> showTaskAddEditDialog(
  BuildContext context, {
  Task? taskToEdit,
  String? householdId,
  fb.User? currentUser,
  Future<void> Function()? onBulkImportTap,
  String? initialTitle,
  String? initialDescription,
  DateTime? initialDeadline,
}) async {
  final cubit = context.read<TaskCubit>();

  // Try to default to provided currentUser, otherwise try FirebaseAuth (guarded).
  fb.User? cu = currentUser;
  if (cu == null) {
    try {
      cu = fb.FirebaseAuth.instance.currentUser;
    } catch (_) {
      cu = null;
    }
  }
  // If caller didn't provide householdId, try to discover it from the
  // households collection (members array). This makes the dialog resilient
  // when callers forget to pass household context or when users have a
  // households.members entry but no users/{uid}.householdId set.
  if (householdId == null && cu != null) {
    try {
      final svc = HouseholdService(FirebaseFirestore.instance);
      householdId = await svc.findHouseholdForUser(cu.uid);
      debugPrint('Dialog fallback detected household: $householdId');
    } catch (e) {
      debugPrint('Dialog household discovery failed: $e');
    }
  }

  // Calling showModalBottomSheet after awaiting potential async work above can
  // trigger `use_build_context_synchronously` analyzer warnings. The builder
  // receives the provided context intentionally; it's safe in this flow.
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _TaskAddEditSheet(
      cubit: cubit,
      taskToEdit: taskToEdit,
      householdId: householdId,
      currentUser: cu,
      onBulkImportTap: onBulkImportTap,
      initialTitle: initialTitle,
      initialDescription: initialDescription,
      initialDeadline: initialDeadline,
    ),
  );
}

class _TaskAddEditSheet extends StatefulWidget {
  final TaskCubit cubit;
  final Task? taskToEdit;
  final String? householdId;
  final fb.User? currentUser;
  final Future<void> Function()? onBulkImportTap;
  final String? initialTitle;
  final String? initialDescription;
  final DateTime? initialDeadline;

  const _TaskAddEditSheet({
    required this.cubit,
    this.taskToEdit,
    this.householdId,
    this.currentUser,
    this.onBulkImportTap,
    this.initialTitle,
    this.initialDescription,
    this.initialDeadline,
  });

  @override
  State<_TaskAddEditSheet> createState() => _TaskAddEditSheetState();
}

class _TaskAddEditSheetState extends State<_TaskAddEditSheet> {
  late final TextEditingController titleCtl;
  late final TextEditingController descCtl;
  late final TextEditingController repeatIntervalCtl;
  late final TextEditingController deadlineCtl;
  final List<Map<String, String?>> cachedMembers = <Map<String, String?>>[];

  late TaskPriority selectedPriority;
  String? selectedRoom;
  String? selectedMemberId;
  String? selectedMemberName;
  late bool isHouseholdTask;
  String? selectedAssigneeValue;
  DateTime? deadline;
  late bool isRepeating;
  int repeatInterval = 1;
  String repeatUnit = 'day';
  late final Set<int> selectedRepeatDays;
  late bool reminderEnabled;
  int? reminderOffset;

  TaskCubit get cubit => widget.cubit;
  Task? get taskToEdit => widget.taskToEdit;
  String? get householdId => widget.householdId;
  fb.User? get currentUser => widget.currentUser;
  fb.User? get cu => widget.currentUser;
  String? get defaultName => cu?.displayName ?? cu?.email ?? cu?.uid;
  Future<void> Function()? get onBulkImportTap => widget.onBulkImportTap;
  BuildContext get contextSB => context;

  void setStateSB(VoidCallback fn) => setState(fn);

  void _onTitleChanged() => setState(() {});

  void _parseRepeatRule(String? rule) {
    final raw = (rule ?? '').toLowerCase().trim();
    if (raw.startsWith('every:')) {
      final parts = raw.split(':');
      if (parts.length >= 3) {
        final parsedInterval = int.tryParse(parts[1]) ?? 1;
        repeatInterval = parsedInterval < 1 ? 1 : parsedInterval;
        repeatUnit = parts[2].normalizeRepeatUnit();
      }
      return;
    }
    switch (raw) {
      case 'daily':
      case 'day':
        repeatInterval = 1;
        repeatUnit = 'day';
        break;
      case 'weekly':
      case 'week':
        repeatInterval = 1;
        repeatUnit = 'week';
        break;
      case 'monthly':
      case 'month':
        repeatInterval = 1;
        repeatUnit = 'month';
        break;
      default:
        repeatInterval = 1;
        repeatUnit = 'day';
        break;
    }
  }

  @override
  void initState() {
    super.initState();
    titleCtl = TextEditingController(
      text: taskToEdit != null
          ? sanitizeTaskTitle(taskToEdit!.title)
          : (widget.initialTitle ?? ''),
    );
    descCtl = TextEditingController(
      text: taskToEdit?.description ?? widget.initialDescription ?? '',
    );
    selectedPriority = taskToEdit?.priority ?? TaskPriority.medium;
    selectedRoom = taskToEdit?.room;
    selectedMemberId = taskToEdit?.assignedToId;
    selectedMemberName = taskToEdit?.assignedToName;
    isHouseholdTask = taskToEdit?.isHouseholdTask ?? false;
    selectedAssigneeValue = taskToEdit?.isHouseholdTask == true
        ? 'household'
        : taskToEdit?.assignedToId;
    deadline = taskToEdit?.deadline ?? widget.initialDeadline;
    isRepeating = taskToEdit?.isRepeating ?? true;
    selectedRepeatDays = {
      ...(taskToEdit?.repeatDays?.where((d) => d >= 1 && d <= 7).toSet() ??
          const <int>{}),
    };
    reminderEnabled = taskToEdit?.reminderEnabled ?? false;
    reminderOffset = taskToEdit?.reminderOffsetMinutes;

    _parseRepeatRule(taskToEdit?.repeatRule);
    repeatIntervalCtl = TextEditingController(
      text: repeatInterval.toString(),
    );
    deadlineCtl = TextEditingController(
      text: deadline != null ? deadline!.toLocalIsoDate() : '',
    );

    final defaultName =
        currentUser?.displayName ?? currentUser?.email ?? currentUser?.uid;
    if (householdId != null) {
      selectedMemberId ??= currentUser?.uid;
      selectedMemberName ??= defaultName;
    } else if (selectedMemberName == null && defaultName != null) {
      selectedMemberName = defaultName;
      selectedMemberId ??= currentUser?.uid;
    }

    titleCtl.addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    titleCtl.removeListener(_onTitleChanged);
    titleCtl.dispose();
    descCtl.dispose();
    repeatIntervalCtl.dispose();
    deadlineCtl.dispose();
    super.dispose();
  }

  bool canAdd() {
    final titleOk = titleCtl.text.trim().isNotEmpty;
    if (householdId != null) {
      final assignee = selectedAssigneeValue ?? 'household';
      return titleOk && assignee.isNotEmpty;
    }
    return titleOk;
  }

  List<int>? buildRepeatDaysForSave() {
    if (!isRepeating) return null;
    if (repeatUnit != 'week') return null;
    if (selectedRepeatDays.isEmpty) return null;
    final days = selectedRepeatDays.where((d) => d >= 1 && d <= 7).toList()
      ..sort();
    return days;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return KeyboardInsetPadding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                  Row(
                    children: [
                      if (taskToEdit == null && onBulkImportTap != null)
                        const SizedBox(width: 8),
                      Text(
                        taskToEdit == null ? 'New Task' : 'Edit Task',
                        style: Theme.of(contextSB).textTheme.titleLarge,
                      ),
                      if (taskToEdit == null && widget.onBulkImportTap != null)
                        TextButton.icon(
                          onPressed: () async {
                            final bulkTap = widget.onBulkImportTap;
                            Navigator.pop(contextSB);
                            if (bulkTap != null) {
                              await bulkTap();
                            }
                          },
                          icon: const Icon(Icons.playlist_add_check),
                          label: const Text('Bulk Import'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (taskToEdit == null) ...[
                    Text(
                      'Quick Picks',
                      style: Theme.of(contextSB).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _reminderPresets.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (ctx, i) {
                          final preset = _reminderPresets[i];
                          return ActionChip(
                            label: Text(preset.title),
                            onPressed: () {
                              setStateSB(() {
                                titleCtl.text = preset.title;
                                selectedRoom = preset.room;
                                isRepeating = true;
                                repeatInterval = preset.interval;
                                repeatUnit = preset.unit;
                                repeatIntervalCtl.text = preset.interval
                                    .toString();
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  TextField(
                    controller: titleCtl,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'e.g. Refresh water filter',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Room',
                      style: Theme.of(contextSB).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _taskRoomOptions.map((room) {
                      final isSelected = selectedRoom == room;
                      return ChoiceChip(
                        label: Text(room),
                        selected: isSelected,
                        onSelected: (selected) {
                          setStateSB(() {
                            selectedRoom = selected ? room : null;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Priority',
                      style: Theme.of(contextSB).textTheme.labelMedium,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 40,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: TaskPriority.values.map((p) {
                          final label =
                              p.name[0].toUpperCase() + p.name.substring(1);
                          IconData icon;
                          switch (p) {
                            case TaskPriority.low:
                              icon = Icons.horizontal_rule;
                              break;
                            case TaskPriority.medium:
                              icon = Icons.drag_handle;
                              break;
                            case TaskPriority.high:
                              icon = Icons.dehaze;
                              break;
                            case TaskPriority.urgent:
                              icon = Icons.priority_high;
                              break;
                          }
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(icon, size: 18),
                                  const SizedBox(width: 6),
                                  Text(label),
                                ],
                              ),
                              selected: selectedPriority == p,
                              onSelected: (_) =>
                                  setStateSB(() => selectedPriority = p),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (householdId != null) ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assign to',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('households')
                          .doc(householdId)
                          .snapshots(),
                      builder: (context, hhSnap) {
                        final membersIds = hhSnap.hasData
                            ? ((hhSnap.data!.data()
                                              as Map<
                                                String,
                                                dynamic
                                              >?)?['members']
                                          as List<dynamic>?)
                                      ?.map((e) => e?.toString() ?? '')
                                      .where((s) => s.isNotEmpty)
                                      .toList() ??
                                  <String>[]
                            : <String>[];

                        Widget buildChips(List<Map<String, String?>> members) {
                          return Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.group, size: 18),
                                    SizedBox(width: 6),
                                    Text('Household'),
                                  ],
                                ),
                                selected:
                                    (selectedAssigneeValue ?? 'household') ==
                                    'household',
                                onSelected: (_) => setStateSB(() {
                                  selectedAssigneeValue = 'household';
                                  isHouseholdTask = true;
                                  selectedMemberId = null;
                                  selectedMemberName = null;
                                }),
                              ),
                              ...members.map((member) {
                                final id = member['id'] ?? '';
                                final display = member['display'] ?? 'Member';
                                final photoUrl = member['photoUrl'];
                                log(display);
                                return ChoiceChip(
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      CircleAvatar(
                                        radius: 10,
                                        backgroundImage:
                                            (photoUrl == null ||
                                                photoUrl.isEmpty)
                                            ? null
                                            : NetworkImage(photoUrl),
                                        child:
                                            (photoUrl == null ||
                                                photoUrl.isEmpty)
                                            ? Text(
                                                display.isNotEmpty
                                                    ? display[0].toUpperCase()
                                                    : '?',
                                                style: theme
                                                    .textTheme
                                                    .labelSmall
                                                    ?.copyWith(fontSize: 12),
                                              )
                                            : null,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(display),
                                    ],
                                  ),
                                  selected: selectedAssigneeValue == id,
                                  onSelected: (_) => setStateSB(() {
                                    selectedAssigneeValue = id;
                                    isHouseholdTask = false;
                                    selectedMemberId = id;
                                    selectedMemberName = display;
                                  }),
                                );
                              }),
                            ],
                          );
                        }

                        if (membersIds.isEmpty) {
                          if (cachedMembers.isNotEmpty) {
                            return buildChips(cachedMembers);
                          }
                          return buildChips(const []);
                        }

                        if (membersIds.length <= 10) {
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('users')
                                .where(
                                  FieldPath.documentId,
                                  whereIn: membersIds,
                                )
                                .snapshots(),
                            builder: (context, snap) {
                              final members = <Map<String, String?>>[];
                              if (snap.hasData) {
                                for (final d in snap.data!.docs) {
                                  final m = d.data() as Map<String, dynamic>;
                                  final display =
                                      m['displayName'] as String? ??
                                      m['email'] as String? ??
                                      d.id;
                                  members.add({
                                    'id': d.id,
                                    'display': display,
                                    'photoUrl': m['photoURL'] as String?,
                                  });
                                }
                                members.sort(
                                  (a, b) => membersIds
                                      .indexOf(a['id'] ?? '')
                                      .compareTo(
                                        membersIds.indexOf(b['id'] ?? ''),
                                      ),
                                );
                                cachedMembers
                                  ..clear()
                                  ..addAll(members);
                              }
                              if (members.isEmpty && cachedMembers.isNotEmpty) {
                                return buildChips(cachedMembers);
                              }
                              return buildChips(members);
                            },
                          );
                        }

                        final futureUsers = Future.wait(
                          membersIds.map(
                            (id) => FirebaseFirestore.instance
                                .collection('users')
                                .doc(id)
                                .get(),
                          ),
                        );
                        return FutureBuilder<List<DocumentSnapshot>>(
                          future: futureUsers,
                          builder: (context, snap) {
                            final members = <Map<String, String?>>[];
                            if (snap.hasData) {
                              for (final d in snap.data!) {
                                if (d.exists) {
                                  final m = d.data() as Map<String, dynamic>?;
                                  final display = m == null
                                      ? d.id
                                      : (m['displayName'] ?? m['email'] ?? d.id)
                                            .toString();
                                  members.add({
                                    'id': d.id,
                                    'display': display,
                                    'photoUrl': m?['photoURL'] as String?,
                                  });
                                }
                              }
                              cachedMembers
                                ..clear()
                                ..addAll(members);
                            }
                            if (members.isEmpty && cachedMembers.isNotEmpty) {
                              return buildChips(cachedMembers);
                            }
                            return buildChips(members);
                          },
                        );
                      },
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Assign to',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (cu != null) ...[
                          Builder(
                            builder: (context) {
                              final activeUser = cu!;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: 10,
                                      backgroundImage:
                                          (activeUser.photoURL == null ||
                                              activeUser.photoURL!.isEmpty)
                                          ? null
                                          : NetworkImage(activeUser.photoURL!),
                                      child:
                                          (activeUser.photoURL == null ||
                                              activeUser.photoURL!.isEmpty)
                                          ? Text(
                                              (defaultName?.isNotEmpty ?? false)
                                                  ? defaultName![0].toUpperCase()
                                                  : '?',
                                              style: theme.textTheme.labelSmall
                                                  ?.copyWith(fontSize: 12),
                                            )
                                          : null,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(defaultName ?? 'Me'),
                                  ],
                                ),
                                selected: selectedMemberId == activeUser.uid,
                                onSelected: (_) => setStateSB(() {
                                  selectedMemberId = activeUser.uid;
                                  selectedMemberName = defaultName;
                                }),
                              );
                            },
                          ),
                        ],
                        ChoiceChip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.person_off, size: 18),
                              SizedBox(width: 6),
                              Text('Unassigned'),
                            ],
                          ),
                          selected: selectedMemberId == null,
                          onSelected: (_) => setStateSB(() {
                            selectedMemberId = null;
                            selectedMemberName = null;
                          }),
                        ),
                      ],
                    ),
                  ],
                  TextField(
                    controller: descCtl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: deadlineCtl,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: 'Deadline',
                      suffixIcon: IconButton(
                        tooltip: 'Pick date',
                        icon: const Icon(Icons.calendar_today),
                        onPressed: () async {
                          final now = DateTime.now();
                          final picked = await showDatePicker(
                            context: contextSB,
                            initialDate: deadline ?? now,
                            firstDate: now,
                            lastDate: DateTime(now.year + 5),
                          );
                          if (picked != null) {
                            setStateSB(() {
                              deadline = picked;
                              deadlineCtl.text = '${picked.toLocal()}'.split(
                                ' ',
                              )[0];
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Repeat'),
                    value: isRepeating,
                    onChanged: (v) => setStateSB(() => isRepeating = v),
                  ),
                  if (isRepeating) ...[
                    Row(
                      children: [
                        SizedBox(
                          width: 72,
                          child: TextField(
                            controller: repeatIntervalCtl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Every',
                            ),
                            onChanged: (v) => setStateSB(() {
                              final parsed = int.tryParse(v) ?? 1;
                              repeatInterval = parsed < 1 ? 1 : parsed;
                            }),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: repeatUnit,
                            decoration: const InputDecoration(
                              labelText: 'Unit',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'day',
                                child: Text('Day'),
                              ),
                              DropdownMenuItem(
                                value: 'week',
                                child: Text('Week'),
                              ),
                              DropdownMenuItem(
                                value: 'month',
                                child: Text('Month'),
                              ),
                            ],
                            onChanged: (v) => setStateSB(() {
                              repeatUnit = v ?? 'day';
                            }),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Repeat days (weekly)',
                        style: Theme.of(contextSB).textTheme.labelMedium,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: List.generate(7, (index) {
                        const labels = [
                          'Mon',
                          'Tue',
                          'Wed',
                          'Thu',
                          'Fri',
                          'Sat',
                          'Sun',
                        ];
                        final weekday = index + 1;
                        return FilterChip(
                          label: Text(labels[index]),
                          selected: selectedRepeatDays.contains(weekday),
                          onSelected: repeatUnit == 'week'
                              ? (selected) => setStateSB(() {
                                  if (selected) {
                                    selectedRepeatDays.add(weekday);
                                  } else {
                                    selectedRepeatDays.remove(weekday);
                                  }
                                })
                              : null,
                        );
                      }),
                    ),
                    if (repeatUnit != 'week')
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          'Set Unit to Week to apply selected repeat days.',
                          style: Theme.of(contextSB).textTheme.bodySmall,
                        ),
                      ),
                  ],
                  const SizedBox(height: 8),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reminder'),
                    value: reminderEnabled,
                    onChanged: (v) => setStateSB(() => reminderEnabled = v),
                  ),
                  if (reminderEnabled) ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            initialValue: reminderOffset ?? 60,
                            decoration: const InputDecoration(
                              labelText: 'Notify',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 0,
                                child: Text('At due time'),
                              ),
                              DropdownMenuItem(
                                value: 15,
                                child: Text('15 minutes before'),
                              ),
                              DropdownMenuItem(
                                value: 30,
                                child: Text('30 minutes before'),
                              ),
                              DropdownMenuItem(
                                value: 60,
                                child: Text('1 hour before'),
                              ),
                              DropdownMenuItem(
                                value: 120,
                                child: Text('2 hours before'),
                              ),
                            ],
                            onChanged: (v) =>
                                setStateSB(() => reminderOffset = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: canAdd()
                            ? () {
                                final editingTask = widget.taskToEdit;
                                if (editingTask != null) {
                                  final sanitizedTitle = sanitizeTaskTitle(
                                    titleCtl.text,
                                  ).capitalizeFirst();
                                  final updated = editingTask.copyWith(
                                    title: sanitizedTitle,
                                    description: descCtl.text.isEmpty
                                        ? null
                                        : descCtl.text,
                                    room: selectedRoom,
                                    assignedToId: isHouseholdTask
                                        ? null
                                        : selectedMemberId,
                                    assignedToName: householdId == null
                                        ? selectedMemberName
                                        : (isHouseholdTask
                                              ? null
                                              : selectedMemberName),
                                    priority: selectedPriority,
                                    deadline: deadline,
                                    isRepeating: isRepeating,
                                    repeatRule: isRepeating
                                        ? 'every:$repeatInterval:$repeatUnit'
                                        : null,
                                    repeatDays: buildRepeatDaysForSave(),
                                    isHouseholdTask: isHouseholdTask,
                                    reminderEnabled: reminderEnabled,
                                    reminderOffsetMinutes: reminderOffset,
                                  );
                                  cubit.updateTask(updated);
                                } else {
                                  final id = const Uuid().v4();
                                  final sanitizedTitle = sanitizeTaskTitle(
                                    titleCtl.text,
                                  ).capitalizeFirst();
                                  final task = Task(
                                    id: id,
                                    title: sanitizedTitle,
                                    description: descCtl.text.isEmpty
                                        ? null
                                        : descCtl.text,
                                    room: selectedRoom,
                                    assignedToId: isHouseholdTask
                                        ? null
                                        : selectedMemberId,
                                    assignedToName: householdId == null
                                        ? selectedMemberName
                                        : (isHouseholdTask
                                              ? null
                                              : selectedMemberName),
                                    priority: selectedPriority,
                                    deadline: deadline,
                                    isRepeating: isRepeating,
                                    repeatRule: isRepeating
                                        ? 'every:$repeatInterval:$repeatUnit'
                                        : null,
                                    repeatDays: buildRepeatDaysForSave(),
                                    isHouseholdTask: isHouseholdTask,
                                    householdId: householdId,
                                    reminderEnabled: reminderEnabled,
                                    reminderOffsetMinutes: reminderOffset,
                                  );
                                  cubit.addTask(task);
                                }
                                AppHaptics.instance.confirm();
                                Navigator.pop(context);
                              }
                            : null,
                        child: Text(taskToEdit == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
  }
}

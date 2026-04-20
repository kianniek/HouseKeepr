import 'dart:convert';
import 'dart:io';
// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:in_app_update/in_app_update.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../models/home.dart';
import '../cubits/task_cubit.dart';
import '../firestore/firestore_home_repository.dart';
import 'profile_menu.dart';
import 'household_page.dart' show TaskListTile;
import 'task_add_dialog.dart';
import '../services/household_service.dart';
import 'shopping_add_dialog.dart';
import 'smart_shopping_list_page.dart';

// Helper to fetch display names for a list of user IDs
Future<List<String>> getDisplayNames(List<String> memberIds) async {
  if (memberIds.isEmpty) return [];
  final firestore = FirebaseFirestore.instance;
  try {
    debugPrint('getDisplayNames: fetching ${memberIds.length} users');
  } catch (_) {}
  final users = await Future.wait(
    memberIds.map((id) async {
      try {
        final path = 'users/$id';
        debugPrint('getDisplayNames: fetching $path');
        final doc = await firestore.collection('users').doc(id).get();
        final data = doc.data();
        return (data != null && data['displayName'] != null)
            ? data['displayName'] as String
            : id;
      } catch (e) {
        debugPrint('getDisplayNames: failed to fetch user $id: $e');
        return id;
      }
    }),
  );
  return users;
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
  final fb.User user;
  const HomeScreen({super.key, required this.user});
}

class _HomeScreenState extends State<HomeScreen> {
  int _bottomNavIndex = 0; // 0 = Home, 1 = Tasks, 2 = Shopping, 3 = Tools
  final int _feedIndex = 0; // 0 = For You, 1 = Everyone
  String? _cachedHouseholdId;
  bool _updateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkForUpdates());
  }

  Future<void> _checkForUpdates() async {
    if (_updateChecked) return;
    _updateChecked = true;

    if (kIsWeb || !Platform.isAndroid || !kReleaseMode) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          if (!mounted) return;
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e, st) {
      debugPrint('In-app update check failed: $e\n$st');
    }
  }

  Future<String?> _detectHouseholdId() async {
    if (_cachedHouseholdId != null) return _cachedHouseholdId;
    final svc = HouseholdService(FirebaseFirestore.instance);
    try {
      debugPrint('HomeScreen._detectHouseholdId for user=${widget.user.uid}');
      _cachedHouseholdId = await svc.findHouseholdForUser(widget.user.uid);
    } catch (e) {
      debugPrint('Household detection failed: $e');
      _cachedHouseholdId = null;
    }
    return _cachedHouseholdId;
  }

  @override
  Widget build(BuildContext context) {
    Widget body;
    if (_bottomNavIndex == 0) {
      body = _feedIndex == 0
          ? ForYouFeed(user: widget.user)
          : EveryoneFeed(user: widget.user);
    } else if (_bottomNavIndex == 1) {
      body = const TasksTab();
    } else {
      body = const ShoppingTab();
    }

    FloatingActionButton? fab;
    if (_bottomNavIndex == 1) {
      fab = FloatingActionButton(
        onPressed: () async {
          final householdId = await _detectHouseholdId();
          if (!mounted) return;
          await showTaskAddEditDialog(
            context,
            householdId: householdId,
            currentUser: widget.user,
          );
        },
        child: const Icon(Icons.add),
      );
    } else if (_bottomNavIndex == 2) {
      fab = FloatingActionButton(
        onPressed: () {
          showShoppingAddDialog(context);
        },
        child: const Icon(Icons.add),
      );
    } else {
      fab = null;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HouseKeepr'),
        actions: [ProfileMenu(user: widget.user)],
      ),
      body: SafeArea(
        child: Padding(padding: const EdgeInsets.all(12), child: body),
      ),
      floatingActionButton: fab,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _bottomNavIndex,
        onDestinationSelected: (idx) => setState(() => _bottomNavIndex = idx),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.checklist_outlined),
            selectedIcon: Icon(Icons.checklist),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label: 'Shopping',
          ),
        ],
      ),
    );
  }

  // Dev helper: dump key Firestore collections to the log for quick inspection.
  // ignore: unused_element
  Future<void> _dumpDevCollections() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final uid = widget.user.uid;
      final hid = await _detectHouseholdId();
      debugPrint('DEV DUMP START: user=$uid household=$hid');

      // User tasks
      try {
        final ut = await firestore
            .collection('users')
            .doc(uid)
            .collection('tasks')
            .get();
        debugPrint(
          'DEV DUMP user tasks: count=${ut.docs.length} ids=${ut.docs.map((d) => d.id).join(", ")}',
        );
        if (ut.docs.isNotEmpty) {
          try {
            final serialized = _normalizeForJson(ut.docs.first.data());
            debugPrint('DEV DUMP user tasks sample: ${jsonEncode(serialized)}');
          } catch (e) {
            debugPrint('DEV DUMP user tasks sample error: $e');
          }
        }
      } catch (e) {
        debugPrint('DEV DUMP user tasks error: $e');
      }

      if (hid != null) {
        // Household tasks
        try {
          final hht = await firestore
              .collection('households')
              .doc(hid)
              .collection('tasks')
              .limit(50)
              .get();
          debugPrint(
            'DEV DUMP household tasks: count=${hht.docs.length} ids=${hht.docs.map((d) => d.id).join(", ")}',
          );
          if (hht.docs.isNotEmpty) {
            try {
              final serialized = _normalizeForJson(hht.docs.first.data());
              debugPrint(
                'DEV DUMP household tasks sample: ${jsonEncode(serialized)}',
              );
            } catch (e) {
              debugPrint('DEV DUMP household tasks sample error: $e');
            }
          }
        } catch (e) {
          debugPrint('DEV DUMP household tasks error: $e');
        }

        // Activity logs
        try {
          final act = await firestore
              .collection('activity_logs')
              .where('householdId', isEqualTo: hid)
              .orderBy('timestamp', descending: true)
              .limit(50)
              .get();
          debugPrint(
            'DEV DUMP activity_logs: count=${act.docs.length} ids=${act.docs.map((d) => d.id).join(", ")}',
          );
          if (act.docs.isNotEmpty) {
            try {
              final serialized = _normalizeForJson(act.docs.first.data());
              debugPrint(
                'DEV DUMP activity_logs sample: ${jsonEncode(serialized)}',
              );
            } catch (e) {
              debugPrint('DEV DUMP activity_logs sample error: $e');
            }
          }
        } catch (e) {
          debugPrint('DEV DUMP activity_logs error: $e');
        }

        // Shopping items
        try {
          final shop = await firestore
              .collection('shopping_items')
              .where('householdId', isEqualTo: hid)
              .orderBy('addedAt', descending: true)
              .limit(50)
              .get();
          debugPrint(
            'DEV DUMP shopping_items: count=${shop.docs.length} ids=${shop.docs.map((d) => d.id).join(", ")}',
          );
          if (shop.docs.isNotEmpty) {
            try {
              final serialized = _normalizeForJson(shop.docs.first.data());
              debugPrint(
                'DEV DUMP shopping_items sample: ${jsonEncode(serialized)}',
              );
            } catch (e) {
              debugPrint('DEV DUMP shopping_items sample error: $e');
            }
          }
        } catch (e) {
          debugPrint('DEV DUMP shopping_items error: $e');
        }
      } else {
        debugPrint(
          'DEV DUMP: no householdId detected; skipping household-scoped collections',
        );
      }

      debugPrint('DEV DUMP END');
    } catch (e) {
      debugPrint('DEV DUMP top-level error: $e');
    }
  }

  // Normalize Firestore document data to JSON-serializable values
  Map<String, dynamic> _normalizeForJson(Map<String, dynamic> src) {
    dynamic normalize(dynamic v) {
      try {
        if (v is Timestamp) return v.toDate().toIso8601String();
      } catch (_) {}
      if (v is Map) {
        return Map<String, dynamic>.from(
          v.map((k, val) => MapEntry(k.toString(), normalize(val))),
        );
      }
      if (v is List) return v.map(normalize).toList();
      return v;
    }

    return Map<String, dynamic>.from(
      src.map((k, v) => MapEntry(k, normalize(v))),
    );
  }
}

// Extracted from HouseholdDashboardPage for reuse
class TasksTab extends StatelessWidget {
  const TasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final tasks = state.tasks;
        if (tasks.isEmpty) return const Center(child: Text('No tasks yet.'));
        return ListView.builder(
          itemCount: tasks.length,
          itemBuilder: (context, idx) {
            final t = tasks[idx];
            return Dismissible(
              key: ValueKey(t.id),
              direction: DismissDirection.endToStart,
              background: Container(
                color: Theme.of(context).colorScheme.error,
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Icon(
                  Icons.delete,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
              onDismissed: (_) {
                context.read<TaskCubit>().deleteTask(t.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Deleted "${t.title}"'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () {
                        context.read<TaskCubit>().addTask(t);
                      },
                    ),
                  ),
                );
              },
              child: t.assignedToId == null
                  ? TaskListTile(task: t)
                  : FutureBuilder<DocumentSnapshot>(
                      future: FirebaseFirestore.instance
                          .collection('users')
                          .doc(t.assignedToId)
                          .get(),
                      builder: (context, snap) {
                        Color? userColor;
                        String? resolvedDisplayName;
                        if (snap.hasData && snap.data != null) {
                          final data =
                              snap.data!.data() as Map<String, dynamic>?;
                          if (data != null && data['personalColor'] != null) {
                            userColor = Color(data['personalColor'] as int);
                          }
                          if (data != null) {
                            resolvedDisplayName =
                                data['displayName'] ?? data['email'];
                          }
                        }
                        final displayNameFallback =
                            resolvedDisplayName ??
                            t.assignedToName ??
                            t.assignedToId;
                        return TaskListTile(
                          task: t,
                          tileColor: userColor,
                          assignedToDisplayName: displayNameFallback,
                        );
                      },
                    ),
            );
          },
        );
      },
    );
  }
}

class ShoppingTab extends StatelessWidget {
  const ShoppingTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const SmartShoppingListPage();
  }
}

class ForYouFeed extends StatelessWidget {
  final fb.User user;
  const ForYouFeed({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = FirestoreHomeRepository(FirebaseFirestore.instance);
    return StreamBuilder<Home?>(
      stream: repo.userHome(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final home = snapshot.data;
        if (home == null) {
          return const Center(child: Text('You are not a member of any home.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text('Welcome to ${home.name}!'),
                subtitle: FutureBuilder<List<String>>(
                  future: getDisplayNames(home.members),
                  builder: (context, snap) {
                    if (!snap.hasData) return const Text('Members: ...');
                    final names = snap.data!;
                    return Text('Members: ${names.join(", ")}');
                  },
                ),
              ),
            ),
            // Recent Activity Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Recent Activity'),
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    final q = FirebaseFirestore.instance
                        .collection('activity_logs')
                        .where('householdId', isEqualTo: home.id)
                        .orderBy('timestamp', descending: true)
                        .limit(3);
                    debugPrint(
                      'home_screen activity_logs query: where(householdId==${home.id}) orderBy(timestamp desc) limit(3)',
                    );
                    return q.snapshots().handleError(
                      (e, st) => debugPrint('activity_logs stream error: $e'),
                    );
                  })(),
                  builder: (context, snap) {
                    debugPrint(
                      'activity_logs snapshot: connection=${snap.connectionState} hasData=${snap.hasData} docs=${snap.data?.docs.length ?? 0} error=${snap.error}',
                    );
                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      try {
                        debugPrint(
                          'activity_logs doc ids: ${snap.data!.docs.map((d) => d.id).join(", ")}',
                        );
                      } catch (_) {}
                    }
                    if (snap.hasError) {
                      debugPrint('activity_logs snapshot error: ${snap.error}');
                      return const Text('Error loading activity.');
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Text('Loading...');
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Text('No recent activity.');
                    }
                    final docs = snap.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final desc = data?['description'] ?? 'Activity';
                        final ts = data?['timestamp'] as Timestamp?;
                        final time = ts != null
                            ? ts.toDate().toLocal().toString().substring(0, 16)
                            : '';
                        return Text('• $desc ($time)');
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
            // Upcoming Tasks Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.check_circle_outline),
                title: const Text('Your Upcoming Tasks'),
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    final q = FirebaseFirestore.instance
                        .collection('households')
                        .doc(home.id)
                        .collection('tasks')
                        .where('assigned_to_id', isEqualTo: user.uid)
                        // NOTE: don't filter on 'completed' server-side because some
                        // documents omit the field. Treat missing as false client-side.
                        .orderBy('deadline', descending: false)
                        .limit(
                          10,
                        ); // fetch a few extra so client-side filter still returns results
                    debugPrint(
                      'home_screen household tasks query: where(assigned_to_id==${user.uid}) orderBy(deadline asc) limit(10) on collection households/${home.id}/tasks',
                    );
                    // One-off diagnostic GET to compare with snapshots (debug only)
                    if (kDebugMode) {
                      q
                          .get()
                          .then((r) {
                            try {
                              debugPrint(
                                'home_screen household tasks one-off get: docs=${r.docs.length} ids=${r.docs.map((d) => d.id).join(",")}',
                              );
                            } catch (_) {}
                          })
                          .catchError((e) {
                            debugPrint('household tasks one-off get error: $e');
                          });
                    }
                    return q.snapshots().handleError(
                      (e, st) => debugPrint('household tasks stream error: $e'),
                    );
                  })(),
                  builder: (context, snap) {
                    debugPrint(
                      'household tasks snapshot: connection=${snap.connectionState} hasData=${snap.hasData} docs=${snap.data?.docs.length ?? 0} error=${snap.error}',
                    );
                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      try {
                        debugPrint(
                          'household tasks doc ids: ${snap.data!.docs.map((d) => d.id).join(", ")}',
                        );
                      } catch (_) {}
                    }
                    if (snap.hasError) {
                      debugPrint(
                        'household tasks snapshot error: ${snap.error}',
                      );
                      return const Text('Error loading tasks.');
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Text('Loading...');
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Text('No upcoming tasks.');
                    }
                    // Client-side filter: treat missing 'completed' as false
                    final docs = snap.data!.docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>?;
                      final completed = data == null
                          ? false
                          : (data['completed'] is bool
                                ? data['completed'] as bool
                                : (data['completed'] is String
                                      ? (data['completed']
                                                .toString()
                                                .toLowerCase() ==
                                            'true')
                                      : false));
                      return !completed;
                    }).toList();
                    if (docs.isEmpty) return const Text('No upcoming tasks.');
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final title = data?['title'] ?? 'Task';
                        final dueRaw = data?['deadline'];
                        String dueStr;
                        try {
                          if (dueRaw is Timestamp) {
                            dueStr = dueRaw
                                .toDate()
                                .toLocal()
                                .toString()
                                .substring(0, 10);
                          } else if (dueRaw is String && dueRaw.isNotEmpty) {
                            final dt = DateTime.tryParse(dueRaw);
                            dueStr = dt != null
                                ? dt.toLocal().toString().substring(0, 10)
                                : 'No due date';
                          } else {
                            dueStr = 'No due date';
                          }
                        } catch (_) {
                          dueStr = 'No due date';
                        }
                        return Text('• $title (Due: $dueStr)');
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
            // Shopping List Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.shopping_cart),
                title: const Text('Recently Added Shopping Items'),
                subtitle: StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    final q = FirebaseFirestore.instance
                        .collection('shopping_items')
                        .where('householdId', isEqualTo: home.id)
                        .orderBy('addedAt', descending: true)
                        .limit(3);
                    debugPrint(
                      'home_screen shopping_items query: where(householdId==${home.id}) orderBy(addedAt desc) limit(3)',
                    );
                    return q.snapshots().handleError(
                      (e, st) => debugPrint('shopping_items stream error: $e'),
                    );
                  })(),
                  builder: (context, snap) {
                    debugPrint(
                      'shopping_items snapshot: connection=${snap.connectionState} hasData=${snap.hasData} docs=${snap.data?.docs.length ?? 0} error=${snap.error}',
                    );
                    if (snap.hasData && snap.data!.docs.isNotEmpty) {
                      try {
                        debugPrint(
                          'shopping_items doc ids: ${snap.data!.docs.map((d) => d.id).join(", ")}',
                        );
                      } catch (_) {}
                    }
                    if (snap.hasError) {
                      debugPrint(
                        'shopping_items snapshot error: ${snap.error}',
                      );
                      return const Text('Error loading shopping items.');
                    }
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Text('Loading...');
                    }
                    if (!snap.hasData || snap.data!.docs.isEmpty) {
                      return const Text('No recent shopping items.');
                    }
                    final docs = snap.data!.docs;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final name = data?['name'] ?? 'Item';
                        final cat = data?['category'] ?? '';
                        return Text(
                          '• $name${cat.isNotEmpty ? ' ($cat)' : ''}',
                        );
                      }).toList(),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Removed duplicate _getDisplayNames. Uses top-level getDisplayNames instead.
}

class EveryoneFeed extends StatelessWidget {
  final fb.User user;
  const EveryoneFeed({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final repo = FirestoreHomeRepository(FirebaseFirestore.instance);
    return StreamBuilder<List<Home>>(
      stream: repo.allHomes(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final homes = snapshot.data ?? [];
        if (homes.isEmpty) {
          return const Center(child: Text('No homes found.'));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ...homes.map(
              (home) => Card(
                child: ListTile(
                  title: Text(home.name),
                  subtitle: FutureBuilder<List<String>>(
                    future: getDisplayNames(home.members),
                    builder: (context, snap) {
                      if (!snap.hasData) return const Text('Members: ...');
                      final names = snap.data!;
                      return Text('Members: ${names.join(", ")}');
                    },
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

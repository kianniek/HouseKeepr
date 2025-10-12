import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

class HouseholdDashboardPage extends StatefulWidget {
  final String householdId;
  final fb.User user;
  const HouseholdDashboardPage({
    super.key,
    required this.householdId,
    required this.user,
  });

  @override
  State<HouseholdDashboardPage> createState() => _HouseholdDashboardPageState();
}

class _HouseholdDashboardPageState extends State<HouseholdDashboardPage> {
  String? _inviteCode;
  TextEditingController _joinController = TextEditingController();
  TextEditingController _taskController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _inviteCode = widget.householdId;
  }

  Future<void> _addTask() async {
    if (_taskController.text.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .collection('tasks')
        .add({
          'name': _taskController.text,
          'assigned_to': widget.user.displayName ?? widget.user.email,
          'due_date': null,
          'is_completed': false,
          'created_at': FieldValue.serverTimestamp(),
        });
    _taskController.clear();
  }

  Future<void> _addShoppingItem(String name, {String? category}) async {
    if (name.isEmpty) return;
    await FirebaseFirestore.instance
        .collection('households')
        .doc(widget.householdId)
        .collection('shopping')
        .add({
          'name': name,
          'category': category,
          'in_cart': false,
          'created_at': FieldValue.serverTimestamp(),
        });
  }

  Future<void> _joinHousehold() async {
    final code = _joinController.text.trim();
    if (code.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('households')
        .doc(code)
        .get();
    if (doc.exists) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user.uid)
          .update({'householdId': code});
      setState(() {
        _inviteCode = code;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Joined household!')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid code')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Household Dashboard'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Tasks'),
              Tab(text: 'Shopping'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // Overview tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ListView(
                children: [
                  Text(
                    'Household ID: ${widget.householdId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text('Invite code: $_inviteCode'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _joinController,
                          decoration: const InputDecoration(
                            labelText: 'Enter invite code to join',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _joinHousehold,
                        child: const Text('Join'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Members:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .where('householdId', isEqualTo: widget.householdId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData)
                        return const CircularProgressIndicator();
                      final members = snapshot.data!.docs;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: members.map((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return Text(
                            data['displayName'] ?? data['email'] ?? doc.id,
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
              ),
            ),

            // Tasks tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _taskController,
                          decoration: const InputDecoration(
                            labelText: 'Add new task',
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _addTask,
                        child: const Text('Add'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('households')
                          .doc(widget.householdId)
                          .collection('tasks')
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final tasks = snapshot.data!.docs;
                        if (tasks.isEmpty) return const Text('No tasks yet.');
                        return ListView(
                          children: tasks.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['name'] ?? ''),
                              subtitle: Text(
                                'Assigned to: ${data['assigned_to'] ?? ''}',
                              ),
                              trailing: Checkbox(
                                value: data['is_completed'] ?? false,
                                onChanged: (val) {
                                  doc.reference.update({
                                    'is_completed': val,
                                    'completed_at': val == true
                                        ? FieldValue.serverTimestamp()
                                        : null,
                                  });
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),

            // Shopping tab
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _ShoppingAddRow(
                    onAdd: (name, category) async {
                      await _addShoppingItem(name, category: category);
                    },
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('households')
                          .doc(widget.householdId)
                          .collection('shopping')
                          .orderBy('created_at', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        final items = snapshot.data!.docs;
                        if (items.isEmpty)
                          return const Text('No shopping items');
                        return ListView(
                          children: items.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            return ListTile(
                              title: Text(data['name'] ?? ''),
                              subtitle: data['category'] != null
                                  ? Text(data['category'])
                                  : null,
                              leading: Checkbox(
                                value: data['in_cart'] ?? false,
                                onChanged: (v) =>
                                    doc.reference.update({'in_cart': v}),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.delete),
                                onPressed: () => doc.reference.delete(),
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShoppingAddRow extends StatefulWidget {
  final Future<void> Function(String name, String? category) onAdd;
  const _ShoppingAddRow({required this.onAdd});

  @override
  State<_ShoppingAddRow> createState() => _ShoppingAddRowState();
}

class _ShoppingAddRowState extends State<_ShoppingAddRow> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _cat = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Item'),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 140,
          child: TextField(
            controller: _cat,
            decoration: const InputDecoration(labelText: 'Category'),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            final name = _name.text.trim();
            final cat = _cat.text.trim().isEmpty ? null : _cat.text.trim();
            if (name.isNotEmpty) {
              widget.onAdd(name, cat);
              _name.clear();
              _cat.clear();
            }
          },
          child: const Text('Add'),
        ),
      ],
    );
  }
}

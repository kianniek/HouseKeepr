import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/home.dart';
import '../firestore/remote_home_repository.dart';

/// Minimal page to create a Home. Expects a [RemoteHomeRepository] to be
/// provided so it can persist the new Home.
class CreateHomePage extends StatefulWidget {
  final RemoteHomeRepository repository;
  final String currentUserId;

  const CreateHomePage({
    super.key,
    required this.repository,
    required this.currentUserId,
  });

  @override
  State<CreateHomePage> createState() => _CreateHomePageState();
}

class _CreateHomePageState extends State<CreateHomePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  var _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final id = const Uuid().v4();
    final invite = const Uuid().v4().substring(0, 6).toUpperCase();
    final home = Home(
      id: id,
      name: _nameCtrl.text.trim(),
      createdBy: widget.currentUserId,
      members: [widget.currentUserId],
      inviteCode: invite,
    );
    try {
      await widget.repository.createHome(home);
      if (mounted) Navigator.of(context).pop(home);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create home: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Home')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Home name'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Please enter a name'
                    : null,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _create(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loading ? null : _create,
                child: _loading
                    ? const CircularProgressIndicator()
                    : const Text('Create'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

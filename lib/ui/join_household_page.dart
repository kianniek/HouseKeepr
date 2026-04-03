import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'qr_scanner_page.dart';
import 'package:firebase_auth/firebase_auth.dart';

class JoinHouseholdPage extends StatefulWidget {
  final User user;
  final void Function(String householdId) onJoined;
  const JoinHouseholdPage({
    super.key,
    required this.user,
    required this.onJoined,
  });

  @override
  State<JoinHouseholdPage> createState() => _JoinHouseholdPageState();
}

class _JoinHouseholdPageState extends State<JoinHouseholdPage> {
  final _inviteCtl = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _joinHousehold() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('joinHouseholdByInviteCode');
      final result = await callable.call<Map<String, dynamic>>({
        'inviteCode': _inviteCtl.text.trim(),
      });
      final householdId = result.data['householdId'] as String?;
      if (householdId != null) {
        widget.onJoined(householdId);
      } else {
        setState(
          () => _error = 'Failed to join household: householdId was null.',
        );
      }
    } on FirebaseFunctionsException catch (e) {
      setState(() => _error = e.message ?? 'An unknown error occurred.');
    } catch (e) {
      setState(() => _error = 'Failed to join household: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join Household')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _inviteCtl,
              decoration: const InputDecoration(labelText: 'Invite code'),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                // Open scanner page and get scanned value
                final result = await Navigator.of(context).push<String?>(
                  MaterialPageRoute(builder: (_) => const QRScannerPage()),
                );
                if (result != null && result.isNotEmpty) {
                  // Try to extract code param if a link was scanned
                  String code = result;
                  try {
                    final uri = Uri.tryParse(result);
                    if (uri != null && uri.queryParameters['code'] != null) {
                      code = uri.queryParameters['code']!;
                    }
                  } catch (_) {}
                  setState(() => _inviteCtl.text = code);
                }
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan QR'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ],
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _joinHousehold,
                    child: const Text('Join'),
                  ),
          ],
        ),
      ),
    );
  }
}

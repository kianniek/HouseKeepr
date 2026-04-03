import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatefulWidget {
  final dynamic auth;
  final dynamic googleSignIn;
  final void Function(fb.User user) onSignedIn;

  const LoginPage({
    super.key,
    required this.auth,
    required this.googleSignIn,
    required this.onSignedIn,
  });

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final List<String> _debugLogs = [];

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toString().split('.')[0];
      _debugLogs.add('[$timestamp] $message');
      if (_debugLogs.length > 50) {
        _debugLogs.removeAt(0); // Keep only last 50 logs
      }
    });
    debugPrint('LOGIN_DEBUG: $message');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Welcome to HouseKeepr'),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login),
                    label: const Text('Sign in with Google'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(220, 48),
                      textStyle: textTheme.titleMedium?.copyWith(fontSize: 18),
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      try {
                        _addLog('Sign-in attempt started...');
                        if (kIsWeb) {
                          _addLog('Web platform detected, using popup flow');
                          // Use FirebaseAuth web popup
                          final provider = fb.GoogleAuthProvider();
                          final result = await fb.FirebaseAuth.instance
                              .signInWithPopup(provider);
                          final webUser = result.user;
                          _addLog('Web sign-in result: user=${webUser?.uid}');
                          if (webUser != null) {
                            _addLog('Calling onSignedIn callback');
                            widget.onSignedIn(webUser);
                          }
                        } else {
                          _addLog('Mobile/Desktop platform detected');
                          // Mobile/Desktop flow: use google_sign_in package
                          final googleSignIn =
                              widget.googleSignIn is GoogleSignIn
                              ? widget.googleSignIn as GoogleSignIn
                              : GoogleSignIn();
                          _addLog('Starting Google Sign In...');
                          final GoogleSignInAccount? account =
                              await googleSignIn.signIn();
                          if (account == null) {
                            _addLog('Google Sign In cancelled by user');
                            return;
                          }
                          _addLog('Google account obtained: ${account.email}');
                          final auth = await account.authentication;
                          _addLog(
                            'Got authentication tokens (accessToken=${auth.accessToken != null}, idToken=${auth.idToken != null})',
                          );
                          if (auth.accessToken == null ||
                              auth.idToken == null) {
                            _addLog(
                              'ERROR: Missing tokens! accessToken=${auth.accessToken}, idToken=${auth.idToken}',
                            );
                            if (messenger != null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Failed to get authentication tokens. Check debug log.',
                                  ),
                                ),
                              );
                            }
                            return;
                          }
                          final credential = fb.GoogleAuthProvider.credential(
                            accessToken: auth.accessToken,
                            idToken: auth.idToken,
                          );
                          _addLog('Created Firebase credential, signing in...');
                          final userCredential = await fb.FirebaseAuth.instance
                              .signInWithCredential(credential);
                          final mobileUser = userCredential.user;
                          _addLog(
                            'Firebase sign-in result: user=${mobileUser?.uid}',
                          );
                          if (mobileUser != null) {
                            _addLog('Calling onSignedIn callback');
                            widget.onSignedIn(mobileUser);
                          }
                        }
                      } catch (e, st) {
                        _addLog('ERROR: ${e.runtimeType}: $e');
                        _addLog('Stack: $st');
                        if (messenger != null) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Sign-in failed: $e')),
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sign in to create or join a household',
                    style: textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (kDebugMode)
            // Debug logs scrollable text box
            Container(
              height: 150,
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scheme.outline),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Debug Logs (${_debugLogs.length})',
                          style: textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            setState(() => _debugLogs.clear());
                          },
                          icon: const Icon(Icons.delete, size: 16),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onSurfaceVariant,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _debugLogs.isEmpty
                        ? Center(
                            child: Text(
                              'No logs yet',
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.builder(
                            reverse: true,
                            itemCount: _debugLogs.length,
                            itemBuilder: (context, index) {
                              final logIndex = _debugLogs.length - 1 - index;
                              final log = _debugLogs[logIndex];
                              final isError = log.contains('ERROR');
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 2,
                                ),
                                child: Text(
                                  log,
                                  style: textTheme.bodySmall?.copyWith(
                                    fontSize: 10,
                                    fontFamily: 'Courier',
                                    color: isError
                                        ? scheme.error
                                        : scheme.tertiary,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

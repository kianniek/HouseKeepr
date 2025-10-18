import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Welcome to HouseKeepr'),
            SizedBox(height: 32),
            ElevatedButton.icon(
              icon: Icon(Icons.login),
              label: Text('Sign in with Google'),
              style: ElevatedButton.styleFrom(
                minimumSize: Size(220, 48),
                textStyle: TextStyle(fontSize: 18),
                backgroundColor: Colors.blueAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
              ),
              onPressed: () async {
                final messenger = ScaffoldMessenger.maybeOf(context);
                try {
                  if (kIsWeb) {
                    // Use FirebaseAuth web popup
                    final provider = fb.GoogleAuthProvider();
                    final result = await fb.FirebaseAuth.instance
                        .signInWithPopup(provider);
                    final webUser = result.user;
                    if (webUser != null) {
                      onSignedIn(webUser);
                    }
                  } else {
                    // Mobile/Desktop flow: use google_sign_in package
                    // higher-level wiring can provide a mock or configured
                    // instance.
                    final GoogleSignInAccount? account =
                        await (googleSignIn is GoogleSignIn
                                ? googleSignIn as GoogleSignIn
                                : GoogleSignIn())
                            .signIn();
                    if (account == null) {
                      return;
                    } // user cancelled
                    final auth = await account.authentication;
                    final credential = fb.GoogleAuthProvider.credential(
                      accessToken: auth.accessToken,
                      idToken: auth.idToken,
                    );
                    final userCredential = await fb.FirebaseAuth.instance
                        .signInWithCredential(credential);
                    final mobileUser = userCredential.user;
                    if (mobileUser != null) {
                      onSignedIn(mobileUser);
                    }
                  }
                } catch (e) {
                  // Show a concise, user-facing error and log only a short
                  // message locally. Avoid printing stack traces or tokens
                  // in production logs.
                  debugPrint('Sign-in failed: ${e.toString()}');
                  if (messenger != null) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Sign-in failed. Please try again.'),
                      ),
                    );
                  }
                }
              },
            ),
            SizedBox(height: 16),
            Text(
              'Sign in to create or join a household',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}

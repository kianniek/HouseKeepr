import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

class LoginPage extends StatelessWidget {
  final dynamic auth;
  final dynamic googleSignIn;
  final void Function(fb.User user) onSignedIn;

  const LoginPage({
    Key? key,
    required this.auth,
    required this.googleSignIn,
    required this.onSignedIn,
  }) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to HouseKeepr',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
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
                try {
                  if (kIsWeb) {
                    // Use FirebaseAuth web popup
                    final provider = fb.GoogleAuthProvider();
                    final result = await fb.FirebaseAuth.instance
                        .signInWithPopup(provider);
                    if (result.user != null) {
                      onSignedIn(result.user!);
                    }
                  } else {
                    // Mobile/Desktop flow: use google_sign_in package
                    final GoogleSignInAccount? account = await GoogleSignIn()
                        .signIn();
                    if (account == null) return; // user cancelled
                    final auth = await account.authentication;
                    final credential = fb.GoogleAuthProvider.credential(
                      accessToken: auth.accessToken,
                      idToken: auth.idToken,
                    );
                    final userCredential = await fb.FirebaseAuth.instance
                        .signInWithCredential(credential);
                    if (userCredential.user != null)
                      onSignedIn(userCredential.user!);
                  }
                } catch (e) {
                  // ignore errors for now; consider showing a snackbar
                  print('Sign-in error: $e');
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

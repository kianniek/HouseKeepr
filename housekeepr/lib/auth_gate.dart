// main app screen after login
import 'package:firebase_auth/firebase_auth.dart' hide EmailAuthProvider; // IMPORTANT: 'hide EmailAuthProvider'
import 'package:flutter/material.dart';

import 'home_screen.dart'; // Your app's main screen after successful login
import 'package:firebase_ui_auth/firebase_ui_auth.dart'; // CORRECTED import for SignInScreen
import 'package:firebase_ui_oauth_google/firebase_ui_oauth_google.dart'; // IMPORTANT: This import is needed for GoogleProvider

class AuthGate extends StatelessWidget {
  // IMPORTANT: Replace with your actual Web client ID from Firebase Console
  final String googleWebClientId;

  const AuthGate({super.key, required this.googleWebClientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return SignInScreen(
            providers: [
              EmailAuthProvider(), // CORRECTED: Should be EmailAuthProvider()
              GoogleProvider(clientId: googleWebClientId),
            ],
            headerBuilder: (context, constraints, shrinkOffset) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Image(
                    image: AssetImage('assets/flutterfire_logo.png'), // Ensure this asset exists!
                  ),
                ),
              );
            },
            subtitleBuilder: (context, action) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: action == AuthAction.signIn
                    ? const Text('Welcome to HouseKeepr, please sign in!')
                    : const Text('Welcome to HouseKeepr, please sign up!'),
              );
            },
            footerBuilder: (context, action) {
              return const Padding(
                padding: EdgeInsets.only(top: 16),
                child: Text(
                  'By signing in, you agree to our terms and conditions.',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              );
            },
            // Consider adding a sideBuilder for wider screens if you want, similar to the codelabs.
            // sideBuilder: (context, shrinkOffset) {
            //   return Padding(
            //     padding: const EdgeInsets.all(20),
            //     child: AspectRatio(
            //       aspectRatio: 1,
            //       child: Image.asset('flutterfire_logo.png'),
            //     ),
            //   );
            // },
          );
        }
        // If the user is signed in, show your app's home screen
        return const HomeScreen();
      },
    );
  }
}

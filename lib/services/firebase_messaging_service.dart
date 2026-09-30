import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../cubits/shopping_cubit.dart';
import '../firebase_options.dart';
import '../firestore/firestore_household_grocery_repository.dart';
import '../services/household_service.dart';
import '../services/widget_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, such as Firestore,
  // make sure you call `initializeApp` before using other Firebase services.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  debugPrint('Handling a background message: ${message.messageId}');

  if (message.data['action'] == 'update_shopping_list' ||
      message.data['type'] == 'shopping_update') {
    debugPrint(
      'Firebase Messaging: Received silent shopping list update in background',
    );

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final householdSvc = HouseholdService(FirebaseFirestore.instance);
    final householdId = await householdSvc.findHouseholdForUser(uid);
    if (householdId == null) return;

    final groceryRepo = FirestoreHouseholdGroceryRepository(
      FirebaseFirestore.instance,
      householdId: householdId,
    );

    final items = await groceryRepo.loadItems();
    await WidgetService.instance.init();
    await WidgetService.instance.updateWidgetImmediate(items);
  }
}

class FirebaseMessagingService {
  FirebaseMessagingService._();
  static final FirebaseMessagingService instance = FirebaseMessagingService._();

  ShoppingCubit? _shoppingCubit;

  void init({ShoppingCubit? shoppingCubit, String? householdId}) async {
    _shoppingCubit = shoppingCubit;

    if (kIsWeb) {
      return;
    }

    try {
      FirebaseMessaging messaging = FirebaseMessaging.instance;
      NotificationSettings settings = await messaging.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (householdId != null && householdId.isNotEmpty) {
        await messaging.subscribeToTopic('household_$householdId');
      }

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted permission');
      } else if (settings.authorizationStatus ==
          AuthorizationStatus.provisional) {
        debugPrint('User granted provisional permission');
      } else {
        debugPrint('User declined or has not accepted permission');
      }

      // Register the top-level background handler
      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null) {
          debugPrint(
            'Message also contained a notification: ${message.notification?.title}',
          );
        }

        _handleMessageAction(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleMessageAction(message);
      });

      // Handle initial message if app was terminated
      RemoteMessage? initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleMessageAction(initialMessage);
      }
    } catch (e) {
      debugPrint('Failed to initialize Firebase Messaging: $e');
    }
  }

  void _handleMessageAction(RemoteMessage message) async {
    if (message.data['action'] == 'update_shopping_list' ||
        message.data['type'] == 'shopping_update') {
      if (_shoppingCubit != null) {
        debugPrint('Firebase Messaging: Processing shopping list update');

        await _shoppingCubit!.reloadItems();
      }
    }
  }
}

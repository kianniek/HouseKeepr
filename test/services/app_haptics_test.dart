import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/app_haptics.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppHaptics.channel, null);
  });

  test('AppHaptics sends semantic perform calls on Android when enabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({});
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppHaptics.channel, (call) async {
          calls.add(call);
          return true;
        });

    await AppHaptics.instance.load();
    expect(AppHaptics.instance.enabled, isTrue);

    AppHaptics.instance.confirm();
    AppHaptics.instance.gestureStart();
    AppHaptics.instance.toggleOn();
    await pumpEventQueue();

    expect(calls, hasLength(3));
    expect(calls[0].method, 'perform');
    expect(calls[0].arguments, {'type': 'confirm'});
    expect(calls[1].arguments, {'type': 'gestureStart'});
    expect(calls[2].arguments, {'type': 'toggleOn'});
  });

  test('AppHaptics suppresses dispatches when disabled in settings', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    SharedPreferences.setMockInitialValues({'haptics_enabled_v1': false});
    final calls = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(AppHaptics.channel, (call) async {
          calls.add(call);
          return true;
        });

    await AppHaptics.instance.load();
    expect(AppHaptics.instance.enabled, isFalse);

    AppHaptics.instance.confirm();
    AppHaptics.instance.reject();
    await pumpEventQueue();

    expect(calls, isEmpty);

    await AppHaptics.instance.setEnabled(true);
    AppHaptics.instance.tick();
    await pumpEventQueue();

    expect(calls, hasLength(1));
    expect(calls.first.arguments, {'type': 'tick'});
  });
}

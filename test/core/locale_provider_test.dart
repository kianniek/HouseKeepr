import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/core/locale_provider.dart';
import 'package:housekeepr/core/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocaleProvider.channel, null);
  });

  test('LocaleProvider defaults to null (System default) and persists changes', () async {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;

    final provider = LocaleProvider.instance;
    await provider.load();
    expect(provider.locale, isNull);

    await provider.setLocale(const Locale('nl'));
    expect(provider.locale, const Locale('nl'));

    final prefs = await SharedPreferences.getInstance();
    expect(SettingsRepository(prefs).getLocaleCode(), 'nl');

    await provider.setLocale(null);
    expect(provider.locale, isNull);
    expect(SettingsRepository(prefs).getLocaleCode(), isNull);
  });

  test('LocaleProvider syncs bidirectionally with Android LocaleManager channel', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    String? osLocale = 'nl';
    final List<MethodCall> calls = [];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocaleProvider.channel, (call) async {
          calls.add(call);
          if (call.method == 'getAppLocale') {
            return <String, Object?>{
              'supported': true,
              'languageCode': osLocale,
            };
          }
          if (call.method == 'setAppLocale') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            osLocale = args['languageCode'] as String?;
            return true;
          }
          return null;
        });

    SharedPreferences.setMockInitialValues({});
    final provider = LocaleProvider.instance;
    await provider.load();
    expect(provider.locale, const Locale('nl'));

    await provider.setLocale(const Locale('en'));
    expect(provider.locale, const Locale('en'));
    expect(osLocale, 'en');

    await provider.setLocale(null);
    expect(provider.locale, isNull);
    expect(osLocale, isNull);
  });

  test('LocaleProvider migrates legacy saved locale once when OS reports unset', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    String? pushedCode;

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LocaleProvider.channel, (call) async {
          if (call.method == 'getAppLocale') {
            return <String, Object?>{
              'supported': true,
              'languageCode': null,
            };
          }
          if (call.method == 'setAppLocale') {
            final args = Map<String, dynamic>.from(call.arguments as Map);
            pushedCode = args['languageCode'] as String?;
            return true;
          }
          return null;
        });

    SharedPreferences.setMockInitialValues({'app_locale_v1': 'nl'});
    final provider = LocaleProvider.instance;
    await provider.load();

    expect(provider.locale, const Locale('nl'));
    expect(pushedCode, 'nl');

    final prefs = await SharedPreferences.getInstance();
    expect(SettingsRepository(prefs).isLocaleMigrated(), isTrue);
  });
}

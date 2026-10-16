import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/chinese_conversion_service.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MissingDictionaryBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) => Future.error(StateError('Missing $key'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ChineseConversionService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    service = ChineseConversionService();
  });

  tearDown(() => service.dispose());

  test('defaults to off and tolerates unknown saved modes', () async {
    await service.load();
    expect(service.mode, ChineseConversionMode.off);
    expect(service.convert('繁體漫畫 😊 ABC'), '繁體漫畫 😊 ABC');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(hazukiChineseConversionPreferenceKey, 'unknown');
    await service.load();
    expect(service.mode, ChineseConversionMode.off);
  });

  test('converts traditional characters and phrases to simplified', () async {
    await service.setMode(ChineseConversionMode.simplified);
    expect(service.convert('繁體漫畫，頭髮與發展。😊 ABC 123'), '繁体漫画，头发与发展。😊 ABC 123');
    expect(service.convert(''), '');
  });

  test('traditional conversion distinguishes ambiguous words', () async {
    await service.setMode(ChineseConversionMode.traditional);
    expect(service.convert('漫画：头发、发展、皇后、后来、干杯。😊'), '漫畫：頭髮、發展、皇后、後來、乾杯。😊');
  });

  test('saves and restores selection across service instances', () async {
    await service.setMode(ChineseConversionMode.simplified);
    final restored = ChineseConversionService();
    addTearDown(restored.dispose);
    await restored.load();
    expect(restored.mode, ChineseConversionMode.simplified);
    expect(restored.convert('漫畫'), '漫画');
  });

  test(
    'switching modes clears cached text and off restores the original',
    () async {
      const original = '漫画與頭髮';
      var notifications = 0;
      service.addListener(() => notifications++);
      await service.setMode(ChineseConversionMode.simplified);
      expect(service.convert(original), '漫画与头发');
      expect(service.convert(original), '漫画与头发');
      await service.setMode(ChineseConversionMode.traditional);
      expect(service.convert(original), '漫畫與頭髮');
      await service.setMode(ChineseConversionMode.off);
      expect(service.convert(original), original);
      expect(notifications, 3);
    },
  );

  test(
    'failed dictionary loading preserves the mode and saved preference',
    () async {
      final failing = ChineseConversionService(
        bundle: _MissingDictionaryBundle(),
      );
      addTearDown(failing.dispose);
      await expectLater(
        failing.setMode(ChineseConversionMode.traditional),
        throwsStateError,
      );
      expect(failing.mode, ChineseConversionMode.off);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(hazukiChineseConversionPreferenceKey), isNull);
    },
  );
}

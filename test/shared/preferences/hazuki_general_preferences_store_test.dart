import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/shared/preferences/hazuki_general_preferences_store.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:hazuki/shared/ui_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const store = HazukiGeneralPreferencesStore();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults match the previous call sites', () async {
    expect(await store.loadAutoCheckInEnabled(), isFalse);
    expect(await store.loadAggregateSearchEnabled(), isFalse);
    expect(await store.loadComicIdSearchEnhanceEnabled(), isFalse);
    expect(await store.loadAutoSourceUpdateCheckEnabled(), isTrue);
    expect(await store.loadAutoSoftwareUpdateCheckEnabled(), isTrue);
    expect(await store.loadDiscoverDailyRecommendationEnabled(), isFalse);
    expect(await store.loadComicDetailDynamicColorEnabled(), isFalse);
    expect(await store.loadNoImageModeEnabled(), isFalse);
    expect(await store.loadSearchComicLayoutName(), isNull);
    expect(await store.loadRankingComicLayoutName(), isNull);
  });

  test('reads and writes the existing preference keys', () async {
    SharedPreferences.setMockInitialValues({
      hazukiComicDetailDynamicColorPreferenceKey: true,
      hazukiNoImageModePreferenceKey: true,
      hazukiDiscoverDailyRecommendationEnabledPreferenceKey: true,
      'ranking_comic_layout': 'grid3',
    });
    expect(await store.loadComicDetailDynamicColorEnabled(), isTrue);
    expect(await store.loadNoImageModeEnabled(), isTrue);
    expect(await store.loadDiscoverDailyRecommendationEnabled(), isTrue);
    expect(await store.loadRankingComicLayoutName(), 'grid3');

    await store.saveAutoCheckInEnabled(true);
    await store.saveAggregateSearchEnabled(true);
    await store.saveComicIdSearchEnhanceEnabled(true);
    await store.saveAutoSourceUpdateCheckEnabled(false);
    await store.saveAutoSoftwareUpdateCheckEnabled(false);
    await store.saveSearchComicLayoutName('grid3');
    await store.saveRankingComicLayoutName('list');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hazukiAutoCheckInEnabledPreferenceKey), isTrue);
    expect(prefs.getBool(hazukiAggregateSearchEnabledPreferenceKey), isTrue);
    expect(prefs.getBool(hazukiComicIdSearchEnhancePreferenceKey), isTrue);
    expect(
      prefs.getBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey),
      isFalse,
    );
    expect(
      prefs.getBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey),
      isFalse,
    );
    expect(prefs.getString(hazukiSearchComicLayoutPreferenceKey), 'grid3');
    expect(prefs.getString('ranking_comic_layout'), 'list');
  });

  test('first use date is written once and then kept', () async {
    final first = await store.loadOrInitFirstUseDate();
    expect(DateTime.tryParse(first), isNotNull);
    expect(await store.loadOrInitFirstUseDate(), first);

    SharedPreferences.setMockInitialValues({
      hazukiFirstUseDatePreferenceKey: '2024-01-02T03:04:05.000',
    });
    expect(await store.loadOrInitFirstUseDate(), '2024-01-02T03:04:05.000');
  });
}

import 'package:shared_preferences/shared_preferences.dart';

import '../ui_flags.dart' show hazukiNoImageModePreferenceKey;
import 'hazuki_preference_keys.dart';

/// 功能页面共用的零散偏好项；UI 层通过它读写，不直接接触 SharedPreferences。
class HazukiGeneralPreferencesStore {
  const HazukiGeneralPreferencesStore();

  Future<bool> _getBool(String key, bool fallback) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(key) ?? fallback;
  }

  Future<void> _setBool(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<String?> _getString(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  Future<void> _setString(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  Future<bool> loadAutoCheckInEnabled() =>
      _getBool(hazukiAutoCheckInEnabledPreferenceKey, false);

  Future<void> saveAutoCheckInEnabled(bool value) =>
      _setBool(hazukiAutoCheckInEnabledPreferenceKey, value);

  Future<bool> loadAggregateSearchEnabled() =>
      _getBool(hazukiAggregateSearchEnabledPreferenceKey, false);

  Future<void> saveAggregateSearchEnabled(bool value) =>
      _setBool(hazukiAggregateSearchEnabledPreferenceKey, value);

  Future<bool> loadComicIdSearchEnhanceEnabled() =>
      _getBool(hazukiComicIdSearchEnhancePreferenceKey, false);

  Future<void> saveComicIdSearchEnhanceEnabled(bool value) =>
      _setBool(hazukiComicIdSearchEnhancePreferenceKey, value);

  Future<bool> loadAutoSourceUpdateCheckEnabled() =>
      _getBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey, true);

  Future<void> saveAutoSourceUpdateCheckEnabled(bool value) =>
      _setBool(hazukiAutoSourceUpdateCheckEnabledPreferenceKey, value);

  Future<bool> loadAutoSoftwareUpdateCheckEnabled() =>
      _getBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey, true);

  Future<void> saveAutoSoftwareUpdateCheckEnabled(bool value) =>
      _setBool(hazukiAutoSoftwareUpdateCheckEnabledPreferenceKey, value);

  Future<bool> loadDiscoverDailyRecommendationEnabled() =>
      _getBool(hazukiDiscoverDailyRecommendationEnabledPreferenceKey, false);

  Future<bool> loadComicDetailDynamicColorEnabled() =>
      _getBool(hazukiComicDetailDynamicColorPreferenceKey, false);

  Future<bool> loadNoImageModeEnabled() =>
      _getBool(hazukiNoImageModePreferenceKey, false);

  /// 返回首次使用时间的原始字符串；首次调用时写入当前时间。
  Future<String> loadOrInitFirstUseDate() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(hazukiFirstUseDatePreferenceKey);
    if (saved != null && saved.isNotEmpty) {
      return saved;
    }
    final now = DateTime.now().toIso8601String();
    await prefs.setString(hazukiFirstUseDatePreferenceKey, now);
    return now;
  }

  // 布局枚举定义在各自的 feature 内，这里只存取名称，解码留给调用方。
  Future<String?> loadSearchComicLayoutName() =>
      _getString(hazukiSearchComicLayoutPreferenceKey);

  Future<void> saveSearchComicLayoutName(String name) =>
      _setString(hazukiSearchComicLayoutPreferenceKey, name);

  Future<String?> loadRankingComicLayoutName() =>
      _getString(hazukiRankingComicLayoutPreferenceKey);

  Future<void> saveRankingComicLayoutName(String name) =>
      _setString(hazukiRankingComicLayoutPreferenceKey, name);
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/support/other_settings_actions.dart';
import 'package:hazuki/shared/preferences/hazuki_preference_keys.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('loads and persists aggregate search setting', () async {
    SharedPreferences.setMockInitialValues({
      hazukiAggregateSearchEnabledPreferenceKey: true,
    });

    final settings = await OtherSettingsActions.loadSettings(
      initialUseSystemTitleBar: false,
    );
    expect(settings.aggregateSearchEnabled, isTrue);

    await OtherSettingsActions.toggleAggregateSearch(false);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(hazukiAggregateSearchEnabledPreferenceKey), isFalse);
  });
}

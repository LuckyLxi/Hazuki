import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_navigation_controller.dart';
import 'package:hazuki/features/reader/support/reader_settings_controller.dart';
import 'package:hazuki/features/reader/support/reader_zoom_controller.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';

class _Navigation extends Mock implements ReaderNavigationController {}

class _Zoom extends Mock implements ReaderZoomController {}

class _Display extends ReaderDisplayController {
  _Display() : super(const MethodChannel('test/settings-display'));
  final applied = <(bool, bool, bool, double)>[];
  final volume = <(String, bool)>[];
  final restored = <String>[];
  @override
  Future<void> apply({
    required bool immersiveMode,
    required bool keepScreenOn,
    required bool customBrightness,
    required double brightnessValue,
  }) async {
    applied.add((
      immersiveMode,
      keepScreenOn,
      customBrightness,
      brightnessValue,
    ));
  }

  @override
  Future<void> syncVolumeButtonPaging({
    required bool enabled,
    required String sessionId,
  }) async {
    volume.add((sessionId, enabled));
  }

  @override
  Future<void> restore({required String sessionId}) async {
    restored.add(sessionId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReaderRuntimeState runtime;
  late _Display display;
  late ReaderDisplaySession session;
  late ReaderSettingsController settings;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    runtime = ReaderRuntimeState();
    display = _Display();
    session = ReaderDisplaySession(
      controller: display,
      sessionId: 'reader-settings',
      readSettings: () => runtime.settings,
    );
    settings = ReaderSettingsController(
      runtimeState: runtime,
      settingsStore: const ReaderSettingsStore(),
      navigationController: _Navigation(),
      zoomController: _Zoom(),
      displaySession: session,
      updateState: (update) => update(),
      logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
      logPayload: ([extra]) => extra ?? {},
    );
  });
  tearDown(() {
    session.close();
    runtime.dispose();
  });

  test(
    'display settings persist and apply the updated runtime snapshot',
    () async {
      await settings.toggleImmersiveMode(false);
      await settings.toggleKeepScreenOn(true);
      await settings.toggleCustomBrightness(true);
      await settings.updateBrightness(0.7);
      expect(display.applied.length, 4);
      expect(display.applied.last, (false, true, true, 0.7));
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(ReaderSettingsStore.immersiveModeKey), isFalse);
      expect(prefs.getBool(ReaderSettingsStore.keepScreenOnKey), isTrue);
      expect(prefs.getBool(ReaderSettingsStore.customBrightnessKey), isTrue);
      expect(prefs.getDouble(ReaderSettingsStore.brightnessValueKey), 0.7);
    },
  );

  test('volume paging uses the same display session identity', () async {
    await settings.toggleVolumeButtonTurnPage(true);
    await settings.toggleVolumeButtonTurnPage(false);
    expect(display.volume, [
      ('reader-settings', true),
      ('reader-settings', false),
    ]);
    expect(runtime.volumeButtonTurnPage, isFalse);
    expect(display.applied, isEmpty);
  });

  test(
    'closing the shared session prevents late settings from changing display',
    () async {
      // Persistence yields; closing the session must suppress the later effect.
      final pending = settings.toggleImmersiveMode(true);
      session.close();
      await session.restore();
      await pending;
      await settings.toggleVolumeButtonTurnPage(true);
      expect(display.applied, isEmpty);
      expect(display.volume, isEmpty);
      expect(display.restored, ['reader-settings']);
    },
  );
}

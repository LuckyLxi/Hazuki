import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/debug/debug_favorites_capability.dart';
import 'package:hazuki/services/source/runtime/source_runtime_handle.dart';
import 'package:hazuki/services/source/runtime/source_script_engine.dart';
import 'package:hazuki/services/source/runtime/source_secure_session_storage.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Engine extends Mock implements SourceScriptEngine {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late SourceRuntimeHandle handle;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    handle = SourceRuntimeHandle(
      sourceKey: 'test',
      secureStorage: MemorySourceSecureSessionStorage(),
      ensureInitialized: (_) async {},
      notifyRuntimeStateChanged: (_) {},
    );
    await handle.appLogStore.setCaptureEnabled(true);
  });

  tearDown(() async {
    handle.requestDispose();
    await handle.whenDisposed;
    handle.appLogStore.dispose();
  });

  for (final completesBeforeTimeout in [true, false]) {
    testWidgets(
      completesBeforeTimeout
          ? 'diagnostics keep script results received before the timeout'
          : 'diagnostics time out pending script evaluation and ignore late results',
      (tester) async {
        final engine = _Engine();
        when(() => engine.runtimeId).thenReturn('debug-favorites');
        when(() => engine.close()).thenAnswer((_) async {});
        when(
          () => engine.evaluate(any(), name: any(named: 'name')),
        ).thenAnswer((_) async => true);
        final response = Completer<dynamic>();
        when(
          () => engine.evaluate(
            'this.__hazuki_source.favorites?.loadFolders?.(null)',
            name: 'debug_favorites_loadFolders.js',
          ),
        ).thenAnswer((_) => response.future);
        handle.runtime.engine = engine;
        final capability = SourceFavoritesDebugCapability(
          activeFacade: () => handle.facade,
          currentAccount: () => null,
          ensureFavoriteSessionReady: () async => true,
          loadFavoriteComics:
              ({required int page, required String folderId}) async =>
                  const FavoriteComicsResult.success([]),
        );
        Map<String, dynamic>? result;
        final collecting = capability.collectFavoritesDebugInfo().then(
          (value) => result = value,
        );
        await tester.pump();
        await tester.pump(Duration(seconds: completesBeforeTimeout ? 19 : 21));
        if (completesBeforeTimeout) {
          response.complete({'folders': []});
          await tester.pump();
        }
        final resultAtDeadline = result;
        if (!completesBeforeTimeout) {
          response.complete({
            'folders': ['late'],
          });
          await tester.pump();
        }
        await collecting;
        expect(resultAtDeadline, isNotNull);
        final call =
            (resultAtDeadline!['calls'] as Map)['loadFolders(null)'] as Map;
        expect(call['ok'], completesBeforeTimeout);
        if (completesBeforeTimeout) {
          expect(call['data'], {'folders': []});
        } else {
          expect(call['error'], contains('TimeoutException'));
          expect(call['ok'], isFalse);
        }
      },
    );
  }
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_actions_controller.dart';
import 'package:hazuki/features/reader/support/reader_display_bridge.dart';
import 'package:hazuki/features/reader/support/reader_display_session.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/features/reader/support/reader_progress_reporter.dart';
import 'package:hazuki/features/reader/support/reader_session_controller.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:mocktail/mocktail.dart';

class _Pipeline extends Mock implements ReaderImagePipelineController {}

class _Actions extends Mock implements ReaderActionsController {}

class _Translation extends Mock implements ReaderTranslationController {}

class _Bridge extends Mock implements ReaderDisplayBridge {}

class _Settings extends Mock implements ReaderSettingsStore {}

class _Display extends Mock implements ReaderDisplayController {}

class _Progress extends Fake implements ReadingProgressService {
  final saves = <(String, String, String, int, int)>[];
  Future<Map<String, dynamic>?>? pendingLoad;

  @override
  Future<Map<String, dynamic>?> load({
    required String comicId,
    required String sourceKey,
  }) => pendingLoad ?? Future.value(null);

  @override
  Future<void> save({
    required String comicId,
    required String sourceKey,
    required String epId,
    required String title,
    required int chapterIndex,
    required int pageIndex,
  }) async => saves.add((comicId, sourceKey, epId, chapterIndex, pageIndex));
}

class _CloudReading extends Fake implements SourceCloudReadingGateway {
  _CloudReading(this.supported);

  final bool? supported;
  final queries = <(String, SourceTaskOrigin?)>[];

  @override
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    queries.add((sourceKey, taskOrigin));
    return supported ?? (throw StateError('Capability unavailable'));
  }
}

void main() {
  late ReaderRuntimeState runtime;
  late _Pipeline images;
  late _Actions actions;
  late _Translation translation;
  late _Settings settings;
  late _Display display;
  late ReaderDisplaySession displaySession;
  late _Progress progress;
  late ReaderProgressReporter reporter;
  late List<Object?> reportReasons;
  late List<String> logs;
  late List<int> restoredTargets;
  var viewportRequests = 0;
  var noImages = false;

  ReaderSessionController session({
    bool offline = false,
    SourceCloudReadingGateway? cloudReading,
  }) => ReaderSessionController(
    runtimeState: runtime,
    displayBridge: _Bridge(),
    displaySession: displaySession,
    settingsStore: settings,
    syncPositionToImageIndex: (index, {required trigger}) {
      expect(trigger, 'entry_restore');
      restoredTargets.add(index);
    },
    requestViewportReport: () => viewportRequests++,
    noImageModeEnabled: () => noImages,
    imagePipeline: images,
    actions: actions,
    translation: translation,
    progressReporter: reporter,
    isMounted: () => true,
    updateState: (update) => update(),
    logEvent: (title, {level = 'info', source = 'reader_ui', content}) {
      logs.add(title);
    },
    logPayload: ([extra]) => extra ?? {},
    comicId: 'comic',
    epId: 'old',
    sourceKey: 'bound-source',
    chapterTitle: 'Old chapter',
    chapterIndex: 4,
    widgetImages: const ['first', 'second', 'third'],
    readingProgressService: progress,
    offlineMode: offline,
    cloudReading: cloudReading,
  );

  setUp(() {
    runtime = ReaderRuntimeState()
      ..applyImages(['first', 'second', 'third'])
      ..setCurrentPageIndex(1);
    addTearDown(runtime.dispose);
    images = _Pipeline();
    actions = _Actions();
    translation = _Translation();
    settings = _Settings();
    when(settings.load).thenAnswer((_) async => runtime.settings);
    when(settings.loadRestorePagePosition).thenAnswer((_) async => true);
    when(
      () => settings.saveRestorePagePosition(any()),
    ).thenAnswer((_) async {});
    display = _Display();
    when(
      () => display.apply(
        immersiveMode: any(named: 'immersiveMode'),
        keepScreenOn: any(named: 'keepScreenOn'),
        customBrightness: any(named: 'customBrightness'),
        brightnessValue: any(named: 'brightnessValue'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => display.syncVolumeButtonPaging(
        enabled: any(named: 'enabled'),
        sessionId: 'old-session',
      ),
    ).thenAnswer((_) async {});
    displaySession = ReaderDisplaySession(
      controller: display,
      sessionId: 'old-session',
      readSettings: () => runtime.settings,
    );
    when(
      () => display.restore(sessionId: 'old-session'),
    ).thenAnswer((_) async {});
    progress = _Progress();
    reportReasons = [];
    logs = [];
    restoredTargets = [];
    viewportRequests = 0;
    noImages = false;
    reporter = ReaderProgressReporter(
      comicId: 'comic',
      chapterId: 'old',
      send: (report) async => reportReasons.add(report['reason']),
    );
  });

  test('direct exit stops work and saves and restores once', () async {
    final reader = session();
    reporter.observe(firstImage: 1, lastImage: 1, totalPages: 3);
    reader.dispose();
    reader.dispose();
    await Future<void>.delayed(Duration.zero);

    expect(reader.isActive, isFalse);
    expect(reader.retireForChapterChange(), isFalse);
    expect(reportReasons, ['initial', 'exit']);
    expect(progress.saves, [('comic', 'bound-source', 'old', 4, 1)]);
    expect(logs, ['Reader session closed']);
    verify(images.dispose).called(1);
    verify(actions.dispose).called(1);
    verify(translation.dispose).called(1);
    verify(() => display.restore(sessionId: 'old-session')).called(1);
  });

  test(
    'replacement retires work before disposal and ignores late settings',
    () async {
      final pending = Completer<ReaderSettingsSnapshot>();
      when(settings.load).thenAnswer((_) => pending.future);
      final reader = session();
      reader.initializeEntry(
        position: {'epId': 'old', 'imagePage': 3},
        restoreEntry: true,
      );
      final loading = reader.loadReadingSettings();
      reporter.observe(firstImage: 1, lastImage: 1, totalPages: 3);

      expect(reader.retireForChapterChange(), isTrue);
      expect(reader.isActive, isFalse);
      expect(reader.retireForChapterChange(), isFalse);
      expect(progress.saves, isEmpty);
      verifyNever(translation.dispose);
      reporter.observe(firstImage: 2, lastImage: 2, totalPages: 3);

      pending.complete(runtime.settings);
      await loading;
      // Outgoing widgets can still update their viewport during the transition.
      runtime.setCurrentPageIndex(2);
      reader.dispose();
      reader.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(restoredTargets, isEmpty);
      expect(viewportRequests, 0);
      expect(logs, ['Reader session closed']);
      expect(reportReasons, ['initial', 'chapter']);
      expect(progress.saves, [('comic', 'bound-source', 'old', 4, 1)]);
      verifyInOrder([
        images.retire,
        () => actions.dispose(SourceTaskStopReason.superseded),
        translation.retire,
        translation.dispose,
      ]);
      verifyNever(images.dispose);
      verifyNever(actions.dispose);
      verifyZeroInteractions(display);
    },
  );

  for (final order in [
    ['settings', 'images', 'position'],
    ['settings', 'position', 'images'],
    ['images', 'settings', 'position'],
    ['images', 'position', 'settings'],
    ['position', 'settings', 'images'],
    ['position', 'images', 'settings'],
  ]) {
    test('entry restores once when ready in order $order', () async {
      runtime.applyImages([]);
      final pendingSettings = Completer<ReaderSettingsSnapshot>();
      final pendingPosition = Completer<Map<String, dynamic>?>();
      when(settings.load).thenAnswer((_) => pendingSettings.future);
      progress.pendingLoad = pendingPosition.future;
      final reader = session(offline: true);
      addTearDown(reader.dispose);
      reader.initializeEntry(position: null, restoreEntry: true);
      final loading = reader.loadReadingSettings();
      for (var index = 0; index < order.length; index++) {
        switch (order[index]) {
          case 'settings':
            pendingSettings.complete(runtime.settings);
          case 'images':
            runtime.applyImages(['first', 'second', 'third']);
            reader.onImagesChanged();
          case 'position':
            pendingPosition.complete({'epId': 'old', 'imagePage': 3});
        }
        await Future<void>.delayed(Duration.zero);
        expect(restoredTargets, index == 2 ? [2] : isEmpty);
      }
      await loading;
      reader.initializeEntry(position: null, restoreEntry: true);
      reader.onImagesChanged();
      expect(restoredTargets, [2]);
      verify(settings.loadRestorePagePosition).called(1);
    });
  }

  for (final stop in ['user', 'chapter', 'exit']) {
    test('$stop prevents a late entry preference from restoring', () async {
      final preference = Completer<bool>();
      when(
        settings.loadRestorePagePosition,
      ).thenAnswer((_) => preference.future);
      final reader = session();
      addTearDown(reader.dispose);
      reader.initializeEntry(
        position: {'epId': 'old', 'imagePage': 3},
        restoreEntry: true,
      );
      await reader.loadReadingSettings();
      switch (stop) {
        case 'user':
          reader.cancelEntryRestore();
        case 'chapter':
          reader.retireForChapterChange();
        case 'exit':
          reader.dispose();
      }
      final requests = viewportRequests;
      preference.complete(true);
      await Future<void>.delayed(Duration.zero);
      expect(restoredTargets, isEmpty);
      expect(viewportRequests, requests);
    });
  }

  test('user restore preference wins over a late read', () async {
    final preference = Completer<bool>();
    when(settings.loadRestorePagePosition).thenAnswer((_) => preference.future);
    final reader = session();
    addTearDown(reader.dispose);
    reader.initializeEntry(
      position: {'epId': 'old', 'imagePage': 3},
      restoreEntry: true,
    );
    await reader.loadReadingSettings();
    reader.setRestorePagePosition(false);
    preference.complete(true);
    await Future<void>.delayed(Duration.zero);
    expect(reader.restorePagePosition, isFalse);
    expect(restoredTargets, isEmpty);
    verify(() => settings.saveRestorePagePosition(false)).called(1);
  });

  test('reports measured range only after restore and while active', () async {
    final reader = session();
    addTearDown(reader.dispose);
    reader.initializeEntry(
      position: {'epId': 'old', 'imagePage': 3},
      restoreEntry: true,
    );
    reader.observeVisibleRange(firstImage: 0, lastImage: 0);
    await reader.loadReadingSettings();
    expect(restoredTargets, [2]);
    reader.observeVisibleRange(firstImage: 0, lastImage: 0);
    expect(reportReasons, isEmpty);
    noImages = true;
    reader.observeVisibleRange(firstImage: 2, lastImage: 2);
    expect(reportReasons, isEmpty);
    noImages = false;
    reader.observeVisibleRange(firstImage: 2, lastImage: 2);
    expect(reportReasons, ['initial']);
    reader.setForeground(false);
    reader.observeVisibleRange(firstImage: 0, lastImage: 0);
    reader.setForeground(true);
    reader.retireForChapterChange();
    reader.observeVisibleRange(firstImage: 0, lastImage: 0);
    reader.setForeground(false);
    reader.dispose();
    expect(reportReasons, ['initial', 'background', 'chapter']);
    expect(progress.saves, hasLength(1));
  });

  for (final (label, offline, capability, saves, queries) in [
    ('offline', true, _CloudReading(true), true, false),
    ('no cloud gateway', false, null, true, false),
    ('no cloud capability', false, _CloudReading(false), true, true),
    ('cloud capability', false, _CloudReading(true), false, true),
    ('capability lookup fails', false, _CloudReading(null), false, true),
  ]) {
    test('$label uses the expected local progress policy', () async {
      session(offline: offline, cloudReading: capability).dispose();
      await Future<void>.delayed(Duration.zero);

      expect(
        capability?.queries ?? [],
        queries ? [('bound-source', null)] : [],
      );
      expect(
        progress.saves,
        saves ? [('comic', 'bound-source', 'old', 4, 1)] : [],
      );
    });
  }
}

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
import 'package:hazuki/features/reader/support/reader_view_bindings.dart';
import 'package:hazuki/services/reading_progress_service.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:hazuki/shared/reading/reader_settings_store.dart';
import 'package:mocktail/mocktail.dart';

class _Pipeline extends Mock implements ReaderImagePipelineController {}

class _Actions extends Mock implements ReaderActionsController {}

class _Translation extends Mock implements ReaderTranslationController {}

class _Bindings extends Mock implements ReaderViewBindings {}

class _Bridge extends Mock implements ReaderDisplayBridge {}

class _Settings extends Mock implements ReaderSettingsStore {}

class _Display extends Mock implements ReaderDisplayController {}

class _Progress extends Fake implements ReadingProgressService {
  final saves = <(String, String, String, int, int)>[];

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
  late _Bindings bindings;
  late _Settings settings;
  late _Display display;
  late ReaderDisplaySession displaySession;
  late _Progress progress;
  late ReaderProgressReporter reporter;
  late List<Object?> reportReasons;
  late List<String> logs;
  var settingsReady = false;

  ReaderSessionController session({
    bool offline = false,
    SourceCloudReadingGateway? cloudReading,
  }) => ReaderSessionController(
    runtimeState: runtime,
    displayBridge: _Bridge(),
    displaySession: displaySession,
    settingsStore: settings,
    viewBindings: bindings,
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
    onSettingsReady: () => settingsReady = true,
  );

  setUp(() {
    runtime = ReaderRuntimeState()
      ..applyImages(['first', 'second', 'third'])
      ..setCurrentPageIndex(1);
    addTearDown(runtime.dispose);
    images = _Pipeline();
    actions = _Actions();
    translation = _Translation();
    bindings = _Bindings();
    settings = _Settings();
    display = _Display();
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
    settingsReady = false;
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
    verify(bindings.dispose).called(1);
    verify(translation.dispose).called(1);
    verify(() => display.restore(sessionId: 'old-session')).called(1);
  });

  test(
    'replacement retires work before disposal and ignores late settings',
    () async {
      final pending = Completer<ReaderSettingsSnapshot>();
      when(settings.load).thenAnswer((_) => pending.future);
      final reader = session();
      final loading = reader.loadReadingSettings();
      reporter.observe(firstImage: 1, lastImage: 1, totalPages: 3);

      expect(reader.retireForChapterChange(), isTrue);
      expect(reader.isActive, isFalse);
      expect(reader.retireForChapterChange(), isFalse);
      expect(progress.saves, isEmpty);
      verifyNever(bindings.dispose);
      verifyNever(translation.dispose);
      reporter.observe(firstImage: 2, lastImage: 2, totalPages: 3);

      pending.complete(runtime.settings);
      await loading;
      // Outgoing widgets can still update their viewport during the transition.
      runtime.setCurrentPageIndex(2);
      reader.dispose();
      reader.dispose();
      await Future<void>.delayed(Duration.zero);

      expect(settingsReady, isFalse);
      expect(logs, ['Reader session closed']);
      expect(reportReasons, ['initial', 'chapter']);
      expect(progress.saves, [('comic', 'bound-source', 'old', 4, 1)]);
      verifyInOrder([
        images.retire,
        () => actions.dispose(SourceTaskStopReason.superseded),
        translation.retire,
        bindings.dispose,
        translation.dispose,
      ]);
      verifyNever(images.dispose);
      verifyNever(actions.dispose);
      verifyZeroInteractions(display);
    },
  );

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

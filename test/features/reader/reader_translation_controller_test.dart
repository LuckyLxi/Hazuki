import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/support/reader_translation_controller.dart';
import 'package:hazuki/services/translation/manga_translation_service.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:hazuki/services/translation/models/translation_models.dart';
import 'package:hazuki/services/translation/translation_failure.dart';
import 'package:hazuki/services/translation/translation_glossary_store.dart';
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Service extends Mock implements MangaTranslationService {
  final calls = <(int, CancelToken, bool)>[];
  final pending = <Completer<PageTranslationResult>>[];
  Future<PageTranslationResult> Function(int page)? respond;

  @override
  Future<PageTranslationResult> translatePage({
    required Uint8List imageBytes,
    required String sourceKey,
    required String comicId,
    bool bypassCache = false,
    CancelToken? cancelToken,
  }) {
    final page = imageBytes.single;
    calls.add((page, cancelToken!, bypassCache));
    final completer = Completer<PageTranslationResult>();
    pending.add(completer);
    return Future.any([
      respond?.call(page) ?? completer.future,
      cancelToken.whenCancel.then<PageTranslationResult>(
        (_) => throw const TranslationFailure(TranslationFailureKind.cancelled),
      ),
    ]);
  }

  int releases = 0;

  @override
  Future<void> releaseDetector() async => releases++;
}

class _Models extends TranslationDetectorModelStore {
  _Models(MangaTranslationSettingsStore settings) : super(settings: settings);

  final installed = {'pp_ocrv5_mobile_det', 'comic_text_detector'};

  @override
  Future<void> load() async {}

  @override
  DetectorModelState stateOf(String id) => DetectorModelState(
    status: installed.contains(id)
        ? DetectorModelStatus.installed
        : DetectorModelStatus.notInstalled,
  );

  bool runtimeInstalled = true;

  @override
  bool get isRuntimeInstalled => runtimeInstalled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MangaTranslationSettingsStore settings;
  late _Models models;
  late _Service service;
  late ReaderTranslationController controller;
  late List<TranslationFailure> failures;
  var size = 1;
  final empty = PageTranslationResult(regions: [], terms: []);
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = MangaTranslationSettingsStore();
    await settings.setEnabled(true);
    await settings.setReaderModeOn(true);
    await settings.updateProvider(
      preset: TranslationProviderPreset.openai,
      model: 'vision',
      apiKey: 'key',
    );
    await settings.setDetectorModelId('pp_ocrv5_mobile_det');
    models = _Models(settings);
    size = 1;
    service = _Service();
    failures = [];
    controller = ReaderTranslationController(
      service: service,
      settings: settings,
      models: models,
      glossary: TranslationGlossaryStore(),
      resolveImageBytes: (url) async => Uint8List.fromList([int.parse(url)]),
      images: () => List.generate(10, (index) => '$index'),
      spreadImageIndices: (index) =>
          List.generate(size, (offset) => index * size + offset),
      spreadStartIndex: (index) => index * size,
      spreadSize: () => size,
      sourceKey: 'source',
      comicId: 'comic',
      onFailure: failures.add,
    );
  });
  tearDown(() {
    controller.dispose();
    models.dispose();
    settings.dispose();
  });

  test(
    'uses visible spread plus ahead pages with concurrency capped at two',
    () async {
      size = 2;
      controller.updateWindow(2);
      await tick();
      expect(service.calls.map((call) => call.$1), [4, 5]);
      expect(
        controller.pageState('6').value.status,
        PageTranslationStatus.queued,
      );
      expect(
        controller.pageState('7').value.status,
        PageTranslationStatus.queued,
      );
      expect(
        controller.pageState('8').value.status,
        PageTranslationStatus.queued,
      );
      expect(
        controller.pageState('3').value.status,
        PageTranslationStatus.idle,
      );
      service.pending[0].complete(empty);
      await tick();
      expect(service.calls.map((call) => call.$1), [4, 5, 6]);
    },
  );

  test(
    'visible pages take priority and leaving cancels active and queued work',
    () async {
      controller.updateWindow(0);
      await tick();
      controller.updateWindow(5);
      await tick();
      expect(service.calls[0].$2.isCancelled, isTrue);
      expect(service.calls[1].$2.isCancelled, isTrue);
      expect(service.calls.skip(2).map((call) => call.$1), [5, 6]);
      expect(
        controller.pageState('2').value.status,
        PageTranslationStatus.idle,
      );
      expect(
        controller.pageState('3').value.status,
        PageTranslationStatus.idle,
      );
    },
  );

  test(
    'zero prefetch translates only visible pages and disabling cancels everything',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      expect(service.calls.map((call) => call.$1), [0]);
      await settings.setReaderModeOn(false);
      await tick();
      expect(service.calls.single.$2.isCancelled, isTrue);
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.idle,
      );
      expect(controller.modeOn, isFalse);
    },
  );

  test('three consecutive failures trip the session breaker', () async {
    service.respond = (_) async =>
        throw const TranslationFailure(TranslationFailureKind.network);
    controller.updateWindow(0);
    await tick();
    await tick();
    expect(settings.readerModeOn, isFalse);
    expect(failures.single.kind, TranslationFailureKind.network);
  });

  test('authorization and quota failures trip immediately', () async {
    await settings.setPrefetchAhead(0);
    await tick();
    service.pending.single.completeError(
      const TranslationFailure(TranslationFailureKind.quotaExceeded),
    );
    await tick();
    await tick();
    expect(settings.readerModeOn, isFalse);
    expect(failures.single.kind, TranslationFailureKind.quotaExceeded);
  });

  test('successful pages clear the consecutive failure count', () async {
    await settings.setReaderModeOn(false);
    await settings.setPrefetchAhead(0);
    service.respond = (page) async {
      if (page == 2) return empty;
      throw const TranslationFailure(TranslationFailureKind.network);
    };
    await settings.setReaderModeOn(true);
    for (var page = 0; page <= 4; page++) {
      controller.updateWindow(page);
      await tick();
    }
    expect(settings.readerModeOn, isTrue);
    controller.updateWindow(5);
    await tick();
    await tick();
    expect(settings.readerModeOn, isFalse);
  });

  test(
    'retries a failed page and retranslates visible pages bypassing cache',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      service.pending[0].completeError(
        const TranslationFailure(TranslationFailureKind.network),
      );
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.failed,
      );
      controller.retry('0');
      await tick();
      service.pending[1].complete(empty);
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.done,
      );
      controller.retranslateVisible();
      await tick();
      expect(service.calls.last.$3, isTrue);
    },
  );

  test(
    'retranslates only the selected image in a double-page spread',
    () async {
      size = 2;
      await settings.setPrefetchAhead(0);
      await tick();
      service.pending[0].complete(empty);
      service.pending[1].complete(empty);
      await tick();
      final otherPage = controller.pageState('0').value;

      controller.retranslate('1');
      await tick();
      expect(service.calls.map((call) => call.$1), [0, 1, 1]);
      expect(service.calls.last.$3, isTrue);
      expect(controller.pageState('0').value, same(otherPage));
      service.pending.last.complete(empty);
      await tick();
      expect(
        controller.pageState('1').value.status,
        PageTranslationStatus.done,
      );
    },
  );

  test(
    'retranslation cancels the selected image request and bypasses cache',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      controller.retranslate('0');
      await tick();
      expect(service.calls.first.$2.isCancelled, isTrue);
      expect(service.calls.map((call) => call.$1), [0, 0]);
      expect(service.calls.last.$3, isTrue);
      service.pending.first.complete(empty);
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.translating,
      );
      service.pending.last.complete(empty);
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.done,
      );
    },
  );

  test(
    'retranslates an image outside the automatic window with zero prefetch',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      controller.retranslate('1');
      await tick();
      expect(service.calls.map((call) => call.$1), [0, 1]);
      expect(service.calls.last.$3, isTrue);
      service.pending.first.complete(empty);
      await tick();
      expect(service.calls.last.$2.isCancelled, isFalse);
      expect(
        controller.pageState('1').value.status,
        PageTranslationStatus.translating,
      );
      service.pending.last.complete(empty);
      await tick();
      expect(
        controller.pageState('1').value.status,
        PageTranslationStatus.done,
      );
    },
  );

  test('retries a failed retranslation outside the automatic window', () async {
    await settings.setPrefetchAhead(0);
    await tick();
    service.pending.single.complete(empty);
    await tick();
    final otherPage = controller.pageState('0').value;

    controller.retranslate('1');
    await tick();
    service.pending.last.completeError(
      const TranslationFailure(TranslationFailureKind.network),
    );
    await tick();
    expect(
      controller.pageState('1').value.status,
      PageTranslationStatus.failed,
    );

    controller.retry('1');
    await tick();
    expect(service.calls.map((call) => call.$1), [0, 1, 1]);
    expect(service.calls.last.$3, isTrue);
    expect(controller.pageState('0').value, same(otherPage));
    controller.updateWindow(0);
    expect(service.calls.last.$2.isCancelled, isFalse);
    service.pending.last.complete(empty);
    await tick();
    expect(controller.pageState('1').value.status, PageTranslationStatus.done);
  });

  test('retranslation does not run when manga translation is off', () async {
    await settings.setReaderModeOn(false);
    await tick();
    controller.retranslate('0');
    await tick();
    expect(service.calls, isEmpty);
  });

  test(
    'new prompt and effort discard old results and cancel old requests',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      service.pending[0].complete(empty);
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.done,
      );
      await settings.setCustomSystemPrompt('Use natural dialogue.');
      await tick();
      expect(service.calls, hasLength(2));
      expect(controller.pageState('0').value.result, isNull);
      await settings.updateProvider(
        preset: TranslationProviderPreset.openai,
        reasoningEffort: TranslationReasoningEffort.high,
      );
      await tick();
      expect(service.calls[1].$2.isCancelled, isTrue);
      expect(service.calls, hasLength(3));
    },
  );

  test(
    'switching locator or detector model discards results and cancels requests',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      service.pending[0].complete(empty);
      await tick();
      expect(
        controller.pageState('0').value.status,
        PageTranslationStatus.done,
      );
      await settings.setDetectorModelId('comic_text_detector');
      await tick();
      expect(controller.pageState('0').value.result, isNull);
      expect(service.calls, hasLength(2));
      await settings.setTextLocator(TranslationTextLocator.ai);
      await tick();
      expect(service.calls[1].$2.isCancelled, isTrue);
      expect(service.calls, hasLength(3));
    },
  );

  test(
    'a missing detector model keeps the mode off until AI locating is chosen',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      expect(controller.modeOn, isTrue);
      final releasesBefore = service.releases;
      models.installed.remove('pp_ocrv5_mobile_det');
      await settings.setDetectorModelId('pp_ocrv5_mobile_det');
      await settings.setTargetLanguage(TranslationTargetLanguage.english);
      await tick();
      expect(controller.ready, isFalse);
      expect(controller.modeOn, isFalse);
      expect(service.calls.single.$2.isCancelled, isTrue);
      expect(service.releases, greaterThan(releasesBefore));
      await controller.toggleMode();
      expect(settings.readerModeOn, isTrue);

      await settings.setTextLocator(TranslationTextLocator.ai);
      await tick();
      expect(controller.modeOn, isTrue);
      expect(service.calls, hasLength(2));

      // 本地检测还需要已安装的运行库。
      models.installed.add('pp_ocrv5_mobile_det');
      models.runtimeInstalled = false;
      await settings.setTextLocator(TranslationTextLocator.detector);
      await tick();
      expect(controller.ready, isFalse);
      models.runtimeInstalled = true;
      await settings.setTargetLanguage(TranslationTargetLanguage.japanese);
      await tick();
      expect(controller.ready, isTrue);
    },
  );

  test(
    'unavailable detectors trip immediately and release the detector',
    () async {
      await settings.setPrefetchAhead(0);
      await tick();
      final releasesBefore = service.releases;
      service.pending.single.completeError(
        const TranslationFailure(TranslationFailureKind.detectorUnavailable),
      );
      await tick();
      await tick();
      expect(settings.readerModeOn, isFalse);
      expect(failures.single.kind, TranslationFailureKind.detectorUnavailable);
      expect(service.releases, greaterThan(releasesBefore));
    },
  );

  test('detector inference failures count toward the breaker', () async {
    await settings.setPrefetchAhead(0);
    await tick();
    service.pending.single.completeError(
      const TranslationFailure(TranslationFailureKind.detectorFailed),
    );
    await tick();
    expect(settings.readerModeOn, isTrue);
    expect(
      controller.pageState('0').value.failure?.kind,
      TranslationFailureKind.detectorFailed,
    );
    service.respond = (_) async =>
        throw const TranslationFailure(TranslationFailureKind.detectorFailed);
    controller.updateWindow(1);
    await tick();
    controller.updateWindow(2);
    await tick();
    await tick();
    expect(settings.readerModeOn, isFalse);
    expect(failures.single.kind, TranslationFailureKind.detectorFailed);
  });

  test('disposing the reader releases the detector', () async {
    final releasesBefore = service.releases;
    controller.updateWindow(0);
    await tick();
    controller.dispose();
    expect(service.releases, releasesBefore + 1);
    controller = ReaderTranslationController(
      service: service,
      settings: settings,
      models: models,
      glossary: TranslationGlossaryStore(),
      resolveImageBytes: (url) async => Uint8List.fromList([int.parse(url)]),
      images: () => const [],
      spreadImageIndices: (index) => [index],
      spreadStartIndex: (index) => index,
      spreadSize: () => 1,
      sourceKey: 'source',
      comicId: 'comic',
      onFailure: failures.add,
    );
  });

  test('single page state changes do not notify the entire reader', () async {
    var notifications = 0;
    controller.addListener(() => notifications++);
    controller.updateWindow(0);
    await tick();
    service.pending[0].complete(empty);
    await tick();
    expect(notifications, 0);
    final callsBeforeReset = service.calls.length;
    controller.reset();
    await tick();
    expect(service.calls, hasLength(callsBeforeReset));
    expect(controller.pageState('0').value.status, PageTranslationStatus.idle);
    expect(service.calls.last.$2.isCancelled, isTrue);
  });
}

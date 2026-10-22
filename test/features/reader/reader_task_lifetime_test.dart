import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/support/reader_diagnostics_support.dart';
import 'package:hazuki/features/reader/support/reader_image_pipeline_controller.dart';
import 'package:hazuki/services/source/runtime/source_task_registry.dart';
import 'package:hazuki/services/source/source_capabilities.dart';

class _Source extends Fake implements SourceReaderGateway {
  _Source(this.tasks);
  final SourceTaskRegistry tasks;
  final chapters = <(SourceTaskOrigin?, Completer<List<String>>)>[];
  final images =
      <
        String,
        List<(SourceTaskOrigin?, Completer<PreparedChapterImageData>)>
      >{};
  @override
  Future<List<String>> loadChapterImages({
    required String comicId,
    required String epId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) {
    final result = Completer<List<String>>();
    chapters.add((taskOrigin, result));
    return tasks.run(
      pluginId: sourceKey,
      method: 'fixture.chapter',
      origin: taskOrigin,
      operation: (_) => result.future,
    );
  }

  @override
  Future<PreparedChapterImageData> prepareChapterImageData(
    String imageUrl, {
    required String comicId,
    required String epId,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) {
    final result = Completer<PreparedChapterImageData>();
    (images[imageUrl] ??= []).add((taskOrigin, result));
    return tasks.run(
      pluginId: sourceKey,
      method: 'fixture.image',
      origin: taskOrigin,
      operation: (_) => result.future,
    );
  }

  @override
  bool isLocalImagePath(String value) => false;
  @override
  void evictImageBytesFromMemory(
    Iterable<String> urls, {
    String sourceKey = '',
  }) {}
  @override
  Future<void> evictImageCacheEntries(
    Iterable<String> urls, {
    String sourceKey = '',
  }) async {}
  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) async => Uint8List(0);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);
PreparedChapterImageData _image(double ratio) => PreparedChapterImageData(
  bytes: Uint8List.fromList([1]),
  extension: 'png',
  wasProcessed: false,
  aspectRatio: ratio,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ReaderRuntimeState state;
  late ReaderImagePipelineState pipeline;
  late SourceTaskRegistry tasks;
  late _Source source;
  late ReaderImagePipelineController controller;
  var noImages = true;
  setUp(() {
    noImages = true;
    state = ReaderRuntimeState()..applyImages(['old']);
    pipeline = ReaderImagePipelineState();
    tasks = SourceTaskRegistry();
    source = _Source(tasks);
    final transform = TransformationController();
    addTearDown(transform.dispose);
    addTearDown(state.dispose);
    addTearDown(tasks.dispose);
    controller = ReaderImagePipelineController(
      runtimeState: state,
      pipelineState: pipeline,
      diagnosticsState: ReaderDiagnosticsState(),
      zoomController: transform,
      context: () => throw StateError('unexpected view access'),
      isMounted: () => true,
      updateState: (update) => update(),
      logEvent: (_, {level = 'info', source = 'reader_ui', content}) {},
      logPayload: ([extra]) => extra ?? {},
      logVisiblePageChange: ({required index, required trigger}) {},
      noImageModeEnabled: () => noImages,
      comicId: 'comic',
      epId: 'ep',
      sourceKey: 'one',
      loadImagesErrorBuilder: (error) => '$error',
      sourceService: source,
      taskControl: tasks,
      precacheImageCallback: (_) async {},
    );
    addTearDown(controller.dispose);
  });

  test(
    'replacement chapter cancels old task and discards its late success',
    () async {
      final old = controller.loadChapterImages();
      final next = controller.loadChapterImages();
      expect(
        source.chapters.first.$1!.cancellation!.reason,
        SourceTaskStopReason.superseded,
      );
      source.chapters.last.$2.complete(['new']);
      await next;
      await old;
      source.chapters.first.$2.complete(['late']);
      await _flush();
      expect(state.images, ['new']);
      expect(state.loadImagesError, isNull);
    },
  );

  test(
    'no-image cancellation cannot publish into a new image generation',
    () async {
      noImages = false;
      final old = controller.getImageProvider('image');
      final rejected = expectLater(old, throwsA(isA<SourceTaskCancelled>()));
      await _flush();
      noImages = true;
      controller.handleNoImageModeChanged();
      await rejected;
      noImages = false;
      final next = controller.getImageProvider('image');
      await _flush();
      source.images['image']!.first.$2.complete(_image(9));
      await _flush();
      expect(pipeline.imageAspectRatioCache, isEmpty);
      source.images['image']!.last.$2.complete(_image(2));
      await next;
      expect(pipeline.imageAspectRatioCache['image'], 2);
      expect(pipeline.activeUnscrambleTasks, 0);
      expect(pipeline.providerCache, contains('image'));
    },
  );

  test(
    'window movement releases old image groups and preserves new visible demand',
    () async {
      noImages = false;
      final urls = List.generate(60, (index) => '$index');
      state.applyImages(urls);
      pipeline.resetForImages(urls);
      controller.prefetchAround(0);
      await _flush();
      final stale = source.images['0']!.first.$1!;
      controller.prefetchAround(50);
      await _flush();
      expect(stale.cancellation!.reason, SourceTaskStopReason.superseded);
      expect(source.images['50']!.first.$1!.cancellation!.reason, isNull);
      controller.dispose();
      await _flush();
      expect(tasks.activeTasks, isEmpty);
    },
  );

  test(
    'no-image mode leaves chapter reading alive while disposal cancels it',
    () async {
      final pending = controller.loadChapterImages();
      controller.handleNoImageModeChanged();
      expect(source.chapters.single.$1!.cancellation!.reason, isNull);
      controller.dispose();
      await pending;
      expect(
        source.chapters.single.$1!.cancellation!.reason,
        SourceTaskStopReason.ownerDisposed,
      );
      expect(state.loadImagesError, isNull);
    },
  );

  test(
    'manual image retry uses a new group and leaves no permit behind',
    () async {
      noImages = false;
      final first = controller.getImageProvider('image');
      await _flush();
      final oldOrigin = source.images['image']!.first.$1!;
      source.images['image']!.first.$2.complete(_image(1));
      await first;
      final retry = controller.retryImage('image');
      await _flush();
      final nextOrigin = source.images['image']!.last.$1!;
      expect(nextOrigin.groupId, isNot(oldOrigin.groupId));
      source.images['image']!.last.$2.complete(_image(3));
      await retry;
      expect(pipeline.imageAspectRatioCache['image'], 3);
      expect(pipeline.retryingImageUrls, isEmpty);
      expect(pipeline.activeUnscrambleTasks, 0);
    },
  );
}

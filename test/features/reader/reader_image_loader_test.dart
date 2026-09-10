import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/reader/state/reader_image_pipeline_state.dart';
import 'package:hazuki/features/reader/support/reader_image_loader.dart';
import 'package:hazuki/services/source/source_capabilities.dart';
import 'package:mocktail/mocktail.dart';

class _Source extends Mock implements SourceReaderGateway {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Source source;
  late ReaderImagePipelineState state;
  late ReaderImageLoader loader;
  late List<String> evictions;
  var noImages = false;

  setUp(() {
    source = _Source();
    state = ReaderImagePipelineState();
    evictions = [];
    noImages = false;
    when(() => source.isLocalImagePath(any())).thenReturn(false);
    loader = ReaderImageLoader(
      state: state,
      source: source,
      comicId: 'comic',
      epId: 'chapter',
      sourceKey: 'jm',
      noImageModeEnabled: () => noImages,
      evictImageBytesFromMemory: (urls) =>
          evictions.addAll(urls.map((url) => 'memory:$url')),
      evictImageCacheEntries: (urls) async =>
          evictions.addAll(urls.map((url) => 'disk:$url')),
    );
  });
  tearDown(() => state.dispose());

  void prepare(Future<PreparedChapterImageData> Function(Invocation) answer) {
    when(
      () => source.prepareChapterImageData(
        any(),
        comicId: 'comic',
        epId: 'chapter',
        sourceKey: 'jm',
        useDiskCache: any(named: 'useDiskCache'),
        priority: any(named: 'priority'),
      ),
    ).thenAnswer(answer);
  }

  test(
    'uses prepared dimensions and returns bytes without publishing a provider',
    () async {
      prepare((_) async => _data(ratio: 1.5));
      final result = await loader.load(
        'image',
        useDiskCache: true,
        priority: true,
      );
      expect(result, isA<MemoryImage>());
      expect(state.imageAspectRatioCache['image'], 1.5);
      expect(state.providerCache, isEmpty);
      expect(state.activeUnscrambleTasks, 0);
    },
  );

  test('reads local dimensions without requesting remote image data', () async {
    final directory = await Directory.systemTemp.createTemp(
      'hazuki-reader-loader-',
    );
    final file = File('${directory.path}/image.png');
    await file.writeAsBytes(_png);
    addTearDown(() async {
      await file.delete();
      await directory.delete();
    });
    when(() => source.isLocalImagePath('local')).thenReturn(true);
    when(() => source.normalizeLocalImagePath('local')).thenReturn(file.path);
    final provider = await loader.load('local', useDiskCache: true);
    expect(provider, isA<FileImage>());
    expect(state.imageAspectRatioCache['local'], 1);
    expect(state.activeUnscrambleTasks, 0);
  });

  test('no-image mode rejects work before accessing the source', () async {
    noImages = true;
    await expectLater(
      loader.load('image', useDiskCache: true),
      throwsStateError,
    );
    verifyNever(() => source.isLocalImagePath(any()));
  });

  test(
    'caps concurrent loads and starts a visible request before queued neighbors',
    () async {
      final pending = <String, Completer<PreparedChapterImageData>>{};
      final started = <String>[];
      prepare((call) {
        final url = call.positionalArguments.single as String;
        started.add(url);
        return (pending[url] = Completer<PreparedChapterImageData>()).future;
      });
      final running = [
        for (var i = 0; i < 5; i++) loader.load('$i', useDiskCache: true),
      ];
      final neighbor = loader.load('neighbor', useDiskCache: true);
      final visible = loader.load(
        'visible',
        useDiskCache: true,
        priority: true,
      );
      await Future<void>.delayed(Duration.zero);
      expect(started, ['0', '1', '2', '3', '4']);
      pending['0']!.complete(_data(ratio: 1));
      await running.first;
      await Future<void>.delayed(Duration.zero);
      expect(started.last, 'visible');
      pending['visible']!.complete(_data(ratio: 1));
      await visible;
      await Future<void>.delayed(Duration.zero);
      expect(started.last, 'neighbor');
      for (final completion in pending.values) {
        if (!completion.isCompleted) completion.complete(_data(ratio: 1));
      }
      await Future.wait([...running, neighbor]);
      expect(state.activeUnscrambleTasks, 0);
    },
  );

  test(
    'dispose wakes queued loads without starting more source requests',
    () async {
      final pending = Completer<PreparedChapterImageData>();
      prepare((_) => pending.future);
      final running = [
        for (var i = 0; i < 5; i++) loader.load('$i', useDiskCache: true),
      ];
      final waiting = loader.load('queued', useDiskCache: true);
      final rejected = expectLater(waiting, throwsStateError);
      await Future<void>.delayed(Duration.zero);
      state.dispose();
      await rejected;
      pending.complete(_data(ratio: 1));
      await Future.wait(running);
      expect(state.decodeWaiters, isEmpty);
      expect(state.activeUnscrambleTasks, 0);
    },
  );

  test(
    'concurrent corrupt cache entries retry once without deadlocking permits',
    () async {
      final requests = <(String, bool, bool)>[];
      prepare((call) async {
        final url = call.positionalArguments.single as String;
        final cached = call.namedArguments[#useDiskCache] as bool;
        final priority = call.namedArguments[#priority] as bool;
        requests.add((url, cached, priority));
        return cached ? _data(bytes: Uint8List(0)) : _data();
      });
      final providers = await Future.wait([
        for (var i = 0; i < 5; i++) loader.load('$i', useDiskCache: true),
      ]).timeout(const Duration(seconds: 3));
      expect(providers, hasLength(5));
      expect(requests.where((request) => !request.$2), hasLength(5));
      expect(
        requests.where((request) => !request.$2).every((request) => request.$3),
        isTrue,
      );
      expect(evictions, hasLength(10));
      expect(state.activeUnscrambleTasks, 0);
    },
  );

  test('bad uncached bytes fail without another retry', () async {
    var attempts = 0;
    prepare((_) async {
      attempts++;
      return _data(bytes: Uint8List(0));
    });
    await expectLater(
      loader.load('bad', useDiskCache: false),
      throwsStateError,
    );
    expect(attempts, 1);
    expect(evictions, isEmpty);
    expect(state.activeUnscrambleTasks, 0);
  });
}

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);
PreparedChapterImageData _data({Uint8List? bytes, double? ratio}) =>
    PreparedChapterImageData(
      bytes: bytes ?? _png,
      extension: 'png',
      wasProcessed: false,
      aspectRatio: ratio,
    );

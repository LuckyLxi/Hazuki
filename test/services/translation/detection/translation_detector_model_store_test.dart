import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/translation/detection/onnx_runtime_library.dart';
import 'package:hazuki/services/translation/detection/translation_detector_model_store.dart';
import 'package:hazuki/services/translation/detection/translation_detector_models.dart';
import 'package:hazuki/services/translation/manga_translation_settings_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory directory;
  late HttpServer server;
  late MangaTranslationSettingsStore settings;
  final routes = <String, Future<void> Function(HttpResponse response)>{};

  final onnx = Uint8List.fromList(List.generate(4096, (index) => index % 251));
  final decoy = Uint8List.fromList([9, 9, 9]);
  final tar = Uint8List.fromList(
    TarEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.bytes('pkg/README.md', [1, 2]))
        ..addFile(
          ArchiveFile.bytes('pkg/.cache/huggingface/inference.onnx', decoy),
        )
        ..addFile(ArchiveFile.bytes('pkg/inference.onnx', onnx)),
    ),
  );

  TranslationDetectorModelSpec spec(
    String id,
    String path,
    Uint8List bytes, {
    String? archiveEntry,
    String? digest,
    Set<String>? keepOutputs,
  }) => TranslationDetectorModelSpec(
    keepOutputs: keepOutputs,
    id: id,
    version: 1,
    kind: TranslationDetectorKind.paddleDb,
    url: 'http://${server.address.host}:${server.port}$path',
    downloadBytes: bytes.length,
    sha256: digest ?? sha256.convert(bytes).toString(),
    license: 'Apache-2.0',
    detectionMaxSide: 960,
    archiveEntry: archiveEntry,
  );

  final runtimeLibrary = Uint8List.fromList(
    List.generate(2048, (index) => index % 7),
  );
  final runtimeZip = Uint8List.fromList(
    ZipEncoder().encodeBytes(
      Archive()
        ..addFile(ArchiveFile.bytes('ort/README.md', [1]))
        ..addFile(ArchiveFile.bytes('ort/lib/ort.dll', runtimeLibrary)),
    ),
  );
  final companionLibrary = Uint8List.fromList(
    List.generate(1024, (index) => index % 5),
  );
  final companionZip = Uint8List.fromList(
    ZipEncoder().encodeBytes(
      Archive()..addFile(ArchiveFile.bytes('bin/dep.dll', companionLibrary)),
    ),
  );
  const runtimeVersion = '1.0.0';

  OnnxRuntimeLibraryFile companionSpec({String? digest}) =>
      OnnxRuntimeLibraryFile(
        sources: ['http://${server.address.host}:${server.port}/dep.zip'],
        archiveBytes: companionZip.length,
        archiveEntry: 'bin/dep.dll',
        fileName: 'dep.dll',
        sha256: digest ?? sha256.convert(companionLibrary).toString(),
        entryCompressedBytes: companionZip.length,
      );

  OnnxRuntimeLibrarySpec runtimeSpec({
    List<String> paths = const ['/runtime.zip'],
    String? digest,
    List<OnnxRuntimeLibraryFile> companions = const [],
  }) => OnnxRuntimeLibrarySpec(
    version: runtimeVersion,
    sources: [
      for (final path in paths)
        'http://${server.address.host}:${server.port}$path',
    ],
    archiveBytes: runtimeZip.length,
    archiveEntry: 'ort/lib/ort.dll',
    fileName: 'ort.dll',
    sha256: digest ?? sha256.convert(runtimeLibrary).toString(),
    entryCompressedBytes: runtimeZip.length,
    companions: companions,
  );

  TranslationDetectorModelStore store(
    List<TranslationDetectorModelSpec> specs, {
    DetectorModelVerifier? verify,
    OnnxRuntimeVerifier? verifyRuntime,
    Future<void> Function()? releaseRuntime,
    OnnxRuntimeLibrarySpec? runtime,
  }) => TranslationDetectorModelStore(
    settings: settings,
    supportDirectory: () async => directory,
    verifyLoadable: verify,
    verifyRuntime: verifyRuntime,
    releaseRuntime: releaseRuntime,
    specs: specs,
    runtimeSpec: () => runtime ?? runtimeSpec(),
  );

  File installed(String id) => File(
    p.join(directory.path, 'manga_translation', 'models', id, 'v1.onnx'),
  );

  File installedRuntime([String fileName = 'ort.dll']) => File(
    p.join(
      directory.path,
      'manga_translation',
      'runtime',
      runtimeVersion,
      fileName,
    ),
  );

  Future<void> installRuntime() async {
    await installedRuntime().parent.create(recursive: true);
    await installedRuntime().writeAsBytes(runtimeLibrary);
  }

  Directory partial() => Directory(
    p.join(directory.path, 'manga_translation', 'models', '.partial'),
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    settings = MangaTranslationSettingsStore();
    directory = await Directory.systemTemp.createTemp('hazuki_detector_');
    routes.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      final handler = routes[request.uri.path];
      if (handler == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      await handler(request.response);
    });
  });

  tearDown(() async {
    await server.close(force: true);
    settings.dispose();
    await directory.delete(recursive: true);
  });

  Future<void> serve(HttpResponse response, Uint8List bytes) async {
    response.contentLength = bytes.length;
    response.add(bytes);
    await response.close();
  }

  test('installs a direct ONNX download without selecting it', () async {
    routes['/model.onnx'] = (response) => serve(response, onnx);
    final models = store([spec('direct', '/model.onnx', onnx)]);
    await models.download('direct');
    expect(models.stateOf('direct').status, DetectorModelStatus.installed);
    expect(models.isInstalled('direct'), isTrue);
    expect(await installed('direct').readAsBytes(), onnx);
    expect(models.modelFile('direct')!.path, installed('direct').path);
    expect(partial().listSync(), isEmpty);
    expect(settings.detectorModelId, isNull);
    models.dispose();
  });

  test('removes model files left by older versions on load', () async {
    final current = installed('direct');
    final stale = File(p.join(current.parent.path, 'v0.onnx'));
    await current.parent.create(recursive: true);
    await current.writeAsBytes(onnx);
    await stale.writeAsBytes(onnx);
    final models = store([spec('direct', '/model.onnx', onnx)]);
    await models.load();
    expect(models.isInstalled('direct'), isTrue);
    expect(await current.exists(), isTrue);
    expect(await stale.exists(), isFalse);
    models.dispose();
  });

  test('follows redirects and extracts only the tar model entry', () async {
    await installRuntime();
    routes['/latest.tar'] = (response) async {
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, '/objects/model.tar');
      await response.close();
    };
    routes['/objects/model.tar'] = (response) => serve(response, tar);
    File? verified;
    final models = store(
      [spec('tar', '/latest.tar', tar, archiveEntry: 'inference.onnx')],
      verify: (spec, model, runtime) async {
        verified = model;
        expect(await model.readAsBytes(), onnx);
      },
    );
    await models.download('tar');
    expect(models.stateOf('tar').status, DetectorModelStatus.installed);
    expect(verified, isNotNull);
    expect(await installed('tar').readAsBytes(), onnx);
    expect(partial().listSync(), isEmpty);
    models.dispose();
  });

  test('reports a changed model source on checksum mismatch', () async {
    routes['/model.onnx'] = (response) => serve(response, onnx);
    final models = store([
      spec('changed', '/model.onnx', onnx, digest: '0' * 64),
    ]);
    await models.download('changed');
    final state = models.stateOf('changed');
    expect(state.status, DetectorModelStatus.failed);
    expect(state.failure, DetectorModelFailure.checksumMismatch);
    expect(await installed('changed').exists(), isFalse);
    expect(partial().listSync(), isEmpty);
    models.dispose();
  });

  test('reports network failures and retries with a fresh download', () async {
    final models = store([spec('retry', '/model.onnx', onnx)]);
    await models.download('retry');
    expect(models.stateOf('retry').failure, DetectorModelFailure.network);

    routes['/model.onnx'] = (response) => serve(response, onnx);
    await models.download('retry');
    expect(models.stateOf('retry').status, DetectorModelStatus.installed);
    models.dispose();
  });

  test('reports archives without the model entry and load failures', () async {
    await installRuntime();
    final empty = Uint8List.fromList(
      TarEncoder().encodeBytes(
        Archive()..addFile(ArchiveFile.bytes('pkg/README.md', [1])),
      ),
    );
    routes['/empty.tar'] = (response) => serve(response, empty);
    routes['/model.tar'] = (response) => serve(response, tar);
    final models = store(
      [
        spec('empty', '/empty.tar', empty, archiveEntry: 'inference.onnx'),
        spec('broken', '/model.tar', tar, archiveEntry: 'inference.onnx'),
      ],
      verify: (spec, model, runtime) async {
        if (spec.id == 'broken') throw StateError('load');
      },
    );
    await models.download('empty');
    await models.download('broken');
    expect(
      models.stateOf('empty').failure,
      DetectorModelFailure.invalidArchive,
    );
    expect(models.stateOf('broken').failure, DetectorModelFailure.loadFailed);
    expect(await installed('broken').exists(), isFalse);
    expect(partial().listSync(), isEmpty);
    models.dispose();
  });

  test('prunes models with kept outputs before installing them', () async {
    // 只含 ir_version 字段的最小模型，裁剪后内容不变。
    final minimal = Uint8List.fromList([0x08, 0x07]);
    final truncated = Uint8List.fromList([0x3a, 0x10, 0x01]);
    routes['/minimal.onnx'] = (response) => serve(response, minimal);
    routes['/truncated.onnx'] = (response) => serve(response, truncated);
    final models = store([
      spec('minimal', '/minimal.onnx', minimal, keepOutputs: {'blk'}),
      spec('truncated', '/truncated.onnx', truncated, keepOutputs: {'blk'}),
    ]);
    await models.download('minimal');
    await models.download('truncated');
    expect(await installed('minimal').readAsBytes(), minimal);
    expect(
      models.stateOf('truncated').failure,
      DetectorModelFailure.invalidArchive,
    );
    expect(partial().listSync(), isEmpty);
    models.dispose();
  });

  test('cancels an in-flight download and removes partial files', () async {
    final started = Completer<void>();
    final release = Completer<void>();
    routes['/slow.onnx'] = (response) async {
      response.contentLength = onnx.length;
      response.add(onnx.sublist(0, 1024));
      await response.flush();
      started.complete();
      await release.future;
      try {
        response.add(onnx.sublist(1024));
        await response.close();
      } catch (_) {}
    };
    final models = store([spec('slow', '/slow.onnx', onnx)]);
    final task = models.download('slow');
    await started.future;
    expect(models.stateOf('slow').status, DetectorModelStatus.downloading);
    models.cancel('slow');
    await task;
    release.complete();
    expect(models.stateOf('slow').status, DetectorModelStatus.notInstalled);
    expect(await installed('slow').exists(), isFalse);
    expect(partial().listSync(), isEmpty);
    models.dispose();
  });

  test(
    'load restores installed models and clears stale partial files',
    () async {
      await installed('kept').parent.create(recursive: true);
      await installed('kept').writeAsBytes(onnx);
      await partial().create(recursive: true);
      await File(p.join(partial().path, 'kept.download')).writeAsBytes([1]);
      final models = store([
        spec('kept', '/kept.onnx', onnx),
        spec('missing', '/missing.onnx', onnx),
      ]);
      await models.load();
      expect(models.isInstalled('kept'), isTrue);
      expect(models.isInstalled('missing'), isFalse);
      expect(models.modelFile('missing'), isNull);
      expect(await partial().exists(), isFalse);
      models.dispose();
    },
  );

  test('deleting the selected model clears the selection', () async {
    routes['/model.onnx'] = (response) => serve(response, onnx);
    final models = store([
      spec('selected', '/model.onnx', onnx),
      spec('other', '/model.onnx', onnx),
    ]);
    await models.download('selected');
    await models.download('other');
    await settings.setDetectorModelId('selected');

    await models.delete('other');
    expect(settings.detectorModelId, 'selected');
    await models.delete('selected');
    expect(settings.detectorModelId, isNull);
    expect(models.isInstalled('selected'), isFalse);
    expect(await installed('selected').exists(), isFalse);
    models.dispose();
  });

  group('runtime library', () {
    Directory runtimePartial() => Directory(
      p.join(directory.path, 'manga_translation', 'runtime', '.partial'),
    );

    test(
      'falls back to the next source and verifies before installing',
      () async {
        routes['/runtime.zip'] = (response) => serve(response, runtimeZip);
        final verified = <String>[];
        final models = store(
          const [],
          runtime: runtimeSpec(paths: ['/offline.zip', '/runtime.zip']),
          verifyRuntime: (_, library) async {
            verified.add(library.path);
            expect(await library.readAsBytes(), runtimeLibrary);
          },
        );
        await models.load();
        expect(models.isRuntimeInstalled, isFalse);
        expect(models.runtimeFile, isNull);
        await models.downloadRuntime();
        expect(models.runtimeState.status, DetectorModelStatus.installed);
        expect(verified, hasLength(1));
        expect(models.runtimeFile!.path, installedRuntime().path);
        expect(await installedRuntime().readAsBytes(), runtimeLibrary);
        expect(await runtimePartial().exists(), isFalse);
        models.dispose();
      },
    );

    test('rejects a changed source and libraries that fail to load', () async {
      routes['/runtime.zip'] = (response) => serve(response, runtimeZip);
      final changed = store(const [], runtime: runtimeSpec(digest: '0' * 64));
      await changed.downloadRuntime();
      expect(
        changed.runtimeState.failure,
        DetectorModelFailure.checksumMismatch,
      );
      changed.dispose();

      final broken = store(
        const [],
        verifyRuntime: (_, _) async => throw StateError('load'),
      );
      await broken.downloadRuntime();
      expect(broken.runtimeState.failure, DetectorModelFailure.loadFailed);
      expect(broken.isRuntimeInstalled, isFalse);
      expect(await installedRuntime().exists(), isFalse);
      expect(await runtimePartial().exists(), isFalse);
      broken.dispose();
    });

    test('reports network failures when every source fails', () async {
      final models = store(const [], runtime: runtimeSpec(paths: ['/a', '/b']));
      await models.downloadRuntime();
      expect(models.runtimeState.failure, DetectorModelFailure.network);
      models.dispose();
    });

    test('installs companion libraries beside the runtime', () async {
      routes['/runtime.zip'] = (response) => serve(response, runtimeZip);
      routes['/dep.zip'] = (response) => serve(response, companionZip);
      final siblings = <String>[];
      final models = store(
        const [],
        runtime: runtimeSpec(companions: [companionSpec()]),
        verifyRuntime: (spec, library) async {
          expect(spec.version, runtimeVersion);
          // 校验运行库时依赖库已在同一目录。
          siblings.addAll(
            library.parent.listSync().map((entry) => p.basename(entry.path)),
          );
        },
      );
      await models.downloadRuntime();
      expect(models.runtimeState.status, DetectorModelStatus.installed);
      expect(siblings, containsAll(['ort.dll', 'dep.dll']));
      expect(await installedRuntime('dep.dll').readAsBytes(), companionLibrary);
      expect(await installedRuntime().readAsBytes(), runtimeLibrary);
      models.dispose();

      // 缺少依赖库时视为未安装。
      await installedRuntime('dep.dll').delete();
      final restarted = store(
        const [],
        runtime: runtimeSpec(companions: [companionSpec()]),
      );
      await restarted.load();
      expect(restarted.isRuntimeInstalled, isFalse);
      restarted.dispose();
    });

    test('rejects a changed companion library', () async {
      routes['/runtime.zip'] = (response) => serve(response, runtimeZip);
      routes['/dep.zip'] = (response) => serve(response, companionZip);
      final models = store(
        const [],
        runtime: runtimeSpec(companions: [companionSpec(digest: '0' * 64)]),
      );
      await models.downloadRuntime();
      expect(
        models.runtimeState.failure,
        DetectorModelFailure.checksumMismatch,
      );
      expect(await installedRuntime().exists(), isFalse);
      expect(await installedRuntime('dep.dll').exists(), isFalse);
      models.dispose();
    });

    test('loading removes runtimes of other versions', () async {
      await installRuntime();
      final stale = File(
        p.join(directory.path, 'manga_translation', 'runtime', '0.9.0', 'a'),
      );
      await stale.parent.create(recursive: true);
      await stale.writeAsBytes([1]);
      final models = store(const []);
      await models.load();
      expect(models.isRuntimeInstalled, isTrue);
      expect(await stale.parent.exists(), isFalse);
      models.dispose();
    });

    test('model verification needs the installed runtime', () async {
      routes['/model.onnx'] = (response) => serve(response, onnx);
      final runtimes = <String>[];
      Future<void> verify(spec, model, File runtime) async =>
          runtimes.add(runtime.path);
      final without = store([spec('a', '/model.onnx', onnx)], verify: verify);
      await without.download('a');
      expect(without.isInstalled('a'), isTrue);
      expect(runtimes, isEmpty);
      without.dispose();

      await installRuntime();
      final withRuntime = store([
        spec('b', '/model.onnx', onnx),
      ], verify: verify);
      await withRuntime.download('b');
      expect(runtimes, [installedRuntime().path]);
      withRuntime.dispose();
    });

    test('deleting releases the detector and removes the library', () async {
      await installRuntime();
      var releases = 0;
      final models = store(const [], releaseRuntime: () async => releases++);
      await models.load();
      expect(models.isRuntimeInstalled, isTrue);
      await models.deleteRuntime();
      expect(releases, 1);
      expect(models.isRuntimeInstalled, isFalse);
      expect(models.runtimeDeletePending, isFalse);
      expect(await installedRuntime().exists(), isFalse);
      models.dispose();
    });

    test(
      'locked libraries are deleted on the next load',
      () async {
        await installRuntime();
        final handle = await installedRuntime().open();
        final models = store(const []);
        await models.load();
        await models.deleteRuntime();
        expect(models.runtimeDeletePending, isTrue);
        expect(models.isRuntimeInstalled, isFalse);
        expect(() => models.downloadRuntime(), throwsStateError);
        models.dispose();
        await handle.close();

        final restarted = store(const []);
        await restarted.load();
        expect(restarted.runtimeDeletePending, isFalse);
        expect(restarted.isRuntimeInstalled, isFalse);
        expect(await installedRuntime().exists(), isFalse);
        restarted.dispose();
      },
      // 只有 Windows 会因文件被占用而删除失败。
      skip: !Platform.isWindows,
    );

    test('unsupported platforms have no runtime', () async {
      final models = TranslationDetectorModelStore(
        settings: settings,
        supportDirectory: () async => directory,
        specs: const [],
        runtimeSpec: () => null,
      );
      await models.load();
      expect(models.runtime, isNull);
      expect(models.isRuntimeInstalled, isFalse);
      expect(() => models.downloadRuntime(), throwsUnsupportedError);
      models.dispose();
    });
  });
}

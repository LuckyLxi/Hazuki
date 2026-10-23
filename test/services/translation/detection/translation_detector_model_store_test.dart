import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
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
  }) => TranslationDetectorModelSpec(
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

  TranslationDetectorModelStore store(
    List<TranslationDetectorModelSpec> specs, {
    DetectorModelVerifier? verify,
  }) => TranslationDetectorModelStore(
    settings: settings,
    supportDirectory: () async => directory,
    verifyLoadable: verify,
    specs: specs,
  );

  File installed(String id) => File(
    p.join(directory.path, 'manga_translation', 'models', id, 'v1.onnx'),
  );

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

  test('follows redirects and extracts only the tar model entry', () async {
    routes['/latest.tar'] = (response) async {
      response.statusCode = HttpStatus.found;
      response.headers.set(HttpHeaders.locationHeader, '/objects/model.tar');
      await response.close();
    };
    routes['/objects/model.tar'] = (response) => serve(response, tar);
    File? verified;
    final models = store(
      [spec('tar', '/latest.tar', tar, archiveEntry: 'inference.onnx')],
      verify: (spec, model) async {
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
      verify: (spec, model) async {
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
}

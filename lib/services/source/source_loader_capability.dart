part of '../hazuki_source_service.dart';

extension HazukiSourceServiceSourceLoaderCapability on HazukiSourceService {
  Future<_SourceLoadResult> _downloadOrLoadSourceFiles() async {
    final supportDir = await getApplicationSupportDirectory();
    final sourceDir = Directory('${supportDir.path}/comic_source');
    if (!await sourceDir.exists()) {
      await sourceDir.create(recursive: true);
    }

    final initFile = File('${sourceDir.path}/init.js');
    final jmFile = File('${sourceDir.path}/jm.js');

    if (!await initFile.exists()) {
      final bundledInit = await rootBundle.loadString(_bundledInitAssetPath);
      await initFile.writeAsString(bundledInit);
    }

    if (await jmFile.exists()) {
      return _SourceLoadResult(
        initFile: initFile,
        jmFile: jmFile,
        message: 'source_loaded_from_local_cache',
      );
    }

    final jmScript = await _downloadFromUrls(_jmSourceUrls);
    if (jmScript != null && jmScript.trim().isNotEmpty) {
      await jmFile.writeAsString(jmScript);
      return _SourceLoadResult(
        initFile: initFile,
        jmFile: jmFile,
        message: 'source_downloaded_on_first_launch',
      );
    }

    throw Exception('source_download_failed_without_cache');
  }

  Future<SourceMeta> _loadSourceMetadata(File initFile, File jmFile) async {
    final initScript = await initFile.readAsString();
    final jmScript = await jmFile.readAsString();
    final className = _extractSourceClassName(jmScript);

    _engine?.close();
    final engine = FlutterQjs(hostPromiseRejectionHandler: (_) {});
    engine.dispatch();
    _engine = engine;

    final setGlobal =
        engine.evaluate('(k, v) => { this[k] = v; }') as JSInvokable;
    setGlobal.invoke(['sendMessage', _handleJsMessage]);
    setGlobal.invoke(['appVersion', '1.0.0']);
    setGlobal.free();

    engine.evaluate(initScript, name: 'init.js');
    engine.evaluate(jmScript, name: 'jm.js');
    engine.evaluate(
      "this.__hazuki_source = new $className();",
      name: 'create_source.js',
    );

    final name = (engine.evaluate('this.__hazuki_source.name') ?? '')
        .toString();
    final key = (engine.evaluate('this.__hazuki_source.key') ?? '').toString();
    final version = (engine.evaluate('this.__hazuki_source.version') ?? '')
        .toString();
    final supportsAccount = _asBool(
      engine.evaluate('!!this.__hazuki_source.account?.login'),
    );

    if (name.isEmpty || key.isEmpty || version.isEmpty) {
      throw Exception('source_metadata_incomplete');
    }

    final settingsDefaults = _parseSettingsDefaultMap(
      engine.evaluate('this.__hazuki_source.settings ?? {}'),
    );

    final meta = SourceMeta(
      name: name,
      key: key,
      version: version,
      supportsAccount: supportsAccount,
      settingsDefaults: settingsDefaults,
    );

    _sourceMeta = meta;

    final initResult = engine.evaluate(
      'this.__hazuki_source.init?.()',
      name: 'source_init.js',
    );
    if (initResult is Future) {
      await initResult;
    }

    return meta;
  }
}

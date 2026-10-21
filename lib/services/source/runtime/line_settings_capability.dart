import 'source_operation_context.dart';
import 'source_runtime_facade.dart';

class LineSettingsCapability {
  LineSettingsCapability(this._facade);

  final HazukiSourceFacade _facade;

  Future<Map<String, dynamic>> getSnapshot({
    SourceOperationContext? operationContext,
  }) async {
    return _facade.handle.runOperation(() async {
      final engine = _facade.js.engine;
      final sourceMeta = _facade.sourceMeta;
      if (engine == null || sourceMeta == null) {
        throw Exception('source_not_initialized');
      }

      Future<dynamic> evaluate(String code, {String? name}) =>
          operationContext == null
          ? engine.evaluate(code, name: name)
          : operationContext.evaluate(engine, code, name: name);
      final result = await _facade.js.resolve(
        evaluate('this.__hazuki_source.lines?.snapshot?.() ?? {}'),
      );
      return result is Map ? Map<String, dynamic>.from(result) : {};
    });
  }

  Future<void> updateSetting(String key, dynamic value) async {
    final sourceMeta = _facade.sourceMeta;
    if (sourceMeta == null) {
      throw Exception('source_not_initialized');
    }
    await _facade.saveSourceSetting(sourceMeta.key, key, value);
  }

  Future<void> refresh({
    bool refreshApiDomains = true,
    bool refreshImageHost = true,
    SourceOperationContext? operationContext,
  }) async {
    return _facade.handle.runOperation(() async {
      final engine = _facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }

      Future<dynamic> evaluate(String code, {String? name}) =>
          operationContext == null
          ? engine.evaluate(code, name: name)
          : operationContext.evaluate(engine, code, name: name);
      if (refreshApiDomains) {
        final hasRefreshApi = _facade.js.asBool(
          await evaluate('!!this.__hazuki_source.refreshApiDomains'),
        );
        if (hasRefreshApi) {
          final dynamic result = await evaluate(
            'this.__hazuki_source.refreshApiDomains(false)',
            name: 'source_refresh_api_domains.js',
          );
          await _facade.js.resolve(result);
        }
      }

      if (refreshImageHost) {
        final hasRefreshImg = _facade.js.asBool(
          await evaluate('!!this.__hazuki_source.refreshImgUrl'),
        );
        if (hasRefreshImg) {
          final dynamic result = await evaluate(
            'this.__hazuki_source.refreshImgUrl(false)',
            name: 'source_refresh_image_host.js',
          );
          await _facade.js.resolve(result);
        }
      }
    });
  }
}

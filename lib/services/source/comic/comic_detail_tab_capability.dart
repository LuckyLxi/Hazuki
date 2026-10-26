import 'dart:convert';

import '../account/source_relogin_coordinator.dart';
import '../models/source_task.dart';
import '../plugins/source_detail_tabs.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../runtime/source_runtime_host.dart';

/// 加载插件声明的详情页标签页内容（`comic.loadDetailTab`）。
class SourceComicDetailTabCapability {
  SourceComicDetailTabCapability({
    required SourceRuntimeHost runtimeHost,
    SourceReloginCoordinator? reloginCoordinator,
  }) : _runtimeHost = runtimeHost,
       _reloginCoordinator = reloginCoordinator;

  final SourceRuntimeHost _runtimeHost;
  final SourceReloginCoordinator? _reloginCoordinator;

  String _resolveSourceKey(String sourceKey) => sourceKey.trim().isEmpty
      ? _runtimeHost.activeSourceKey
      : _runtimeHost.normalize(sourceKey);

  Future<List<SourceDetailTabBlock>> loadDetailTab({
    required String comicId,
    required String tabId,
    String sourceKey = '',
    SourceTaskOrigin? taskOrigin,
  }) => runSourceOperation(
    _runtimeHost,
    _runtimeHost.handleFor(_resolveSourceKey(sourceKey)),
    'comic.loadDetailTab',
    (operationContext) => _loadDetailTabTask(
      operationContext,
      comicId: comicId,
      tabId: tabId,
      sourceKey: sourceKey,
    ),
    origin: taskOrigin,
    serviceOwned: false,
  );

  Future<List<SourceDetailTabBlock>> _loadDetailTabTask(
    SourceOperationContext operationContext, {
    required String comicId,
    required String tabId,
    required String sourceKey,
  }) async {
    final facade = _runtimeHost.handleFor(_resolveSourceKey(sourceKey)).facade;
    Future<List<SourceDetailTabBlock>>
    load() => facade.handle.runOperation(() async {
      await facade.ensureInitialized();
      final engine = facade.js.engine;
      if (engine == null) {
        throw Exception('source_not_initialized');
      }
      final dynamic result = await operationContext.evaluate(
        engine,
        'this.__hazuki_source.comic.loadDetailTab(${jsonEncode(comicId)}, ${jsonEncode(tabId)})',
        name: 'source_detail_tab.js',
      );
      final dynamic resolved = await operationContext.resolve(
        facade.js.resolve(result),
      );
      return SourceDetailTabBlock.parseList(resolved);
    });
    final relogin = _reloginCoordinator;
    if (relogin == null) return load();
    return relogin.runWithReloginRetry(
      load,
      context: SourceFacadeReloginContext(facade),
      checkActive: operationContext.checkActive,
    );
  }
}

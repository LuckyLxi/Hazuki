import '../models/source_task.dart';
import '../runtime/source_shared_request.dart';
import '../runtime/source_operation_runner.dart';
import '../runtime/source_operation_context.dart';
import '../debug/debug_log_internals.dart';
import '../interaction/source_ui_scope.dart';
import '../runtime/source_runtime_facade.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';

class SourceLoginSideDataOperations {
  SourceLoginSideDataOperations({
    required SourceRuntimeHost runtimeHost,
    Duration profileLoadTimeout = const Duration(seconds: 15),
  }) : _runtimeHost = runtimeHost,
       _profileLoadTimeout = profileLoadTimeout;
  final SourceRuntimeHost _runtimeHost;
  final Duration _profileLoadTimeout;
  final _profileLoads =
      <
        SourceRuntimeHandle,
        ({String? identity, SourceSharedRequest<String?> request})
      >{};

  String? get cachedAvatarUrl {
    final handle = _runtimeHost.optionalActiveHandle;
    return handle == null ? null : _cachedAvatarUrl(handle.facade);
  }

  String? _cachedAvatarUrl(HazukiSourceFacade facade) {
    final stored = facade
        .loadSourceData(facade.sourceKey, 'avatar_url')
        ?.toString()
        .trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final transient = facade.runtime.transientAvatarUrl?.trim();
    return transient == null || transient.isEmpty ? null : transient;
  }

  Future<void> persistLoginSideData(
    HazukiSourceFacade facade, {
    required String sourceKey,
    required dynamic result,
    void Function()? checkActive,
    Future<void> Function(Future<void> Function())? commit,
  }) async {
    checkActive?.call();
    if (result is! Map) return;
    if (result['avatarUrl'] is String) {
      facade.runtime.transientAvatarUrl = (result['avatarUrl'] as String)
          .trim();
    }
    for (final entry in {
      'token': result['token'],
      'avatar_url': result['avatarUrl'],
      'display_name': result['displayName'],
    }.entries) {
      if (entry.value is String && (entry.value as String).trim().isNotEmpty) {
        await facade.saveSourceData(
          sourceKey,
          entry.key,
          (entry.value as String).trim(),
        );
      }
    }
  }

  Future<String?> loadCurrentAvatarUrl({SourceTaskOrigin? taskOrigin}) async {
    final handle = _runtimeHost.optionalActiveHandle;
    if (handle == null) return null;
    final requestIdentity = handle.session.loginIdentity;
    try {
      return await runSourceOperation(_runtimeHost, handle, 'account.profile', (
        context,
      ) async {
        final identity = handle.session.loginIdentity;
        var request = _profileLoads[handle]?.identity == identity
            ? _profileLoads[handle]?.request
            : null;
        if (request == null || !request.available) {
          late final SourceSharedRequest<String?> created;
          created = SourceSharedRequest<String?>(
            pluginId: handle.sourceKey,
            method: 'account.profile.producer',
            onUnavailable: () {
              if (identical(_profileLoads[handle]?.request, created)) {
                _profileLoads.remove(handle);
              }
            },
            operation: (request) => _loadProfile(handle, identity, request),
          );
          request = created;
          _profileLoads[handle] = (identity: identity, request: request);
        }
        return request.subscribe(task: context.task);
      }, origin: taskOrigin);
    } on SourceTaskTimedOut {
      return (_runtimeHost.isCurrentHandle(handle) &&
              handle.session.loginIdentity == requestIdentity)
          ? _cachedAvatarUrl(handle.facade)
          : null;
    }
  }

  Future<String?> _loadProfile(
    SourceRuntimeHandle handle,
    String? identity,
    SourceSharedRequest<String?> request,
  ) => handle.runOperation(() async {
    final facade = handle.facade;
    try {
      final result = await SourceUiScope.timeout(
        (() async {
          await facade.ensureInitialized();
          request.checkActive();
          final engine = handle.runtime.engine;
          if (engine == null) return null;
          request.bindEngine(engine);
          if (await engine.evaluate(
                'typeof this.__hazuki_source.account?.loadProfile === "function"',
                execution: request.execution,
              ) !=
              true) {
            return null;
          }
          request.checkActive();
          return awaitJsResult(
            await engine.evaluate(
              'this.__hazuki_source.account.loadProfile()',
              execution: request.execution,
            ),
          );
        })(),
        _profileLoadTimeout,
        onTimeout: () => throw SourceTaskTimedOut(
          request.resourceId,
          SourceTaskStopReason.deadlineExceeded,
        ),
      );
      request.checkActive();
      if (!_runtimeHost.isCurrentHandle(handle) ||
          handle.session.loginIdentity != identity ||
          !request.hasConsumers) {
        return null;
      }
      await persistLoginSideData(
        facade,
        sourceKey: handle.sourceKey,
        result: result,
        checkActive: () {
          request.checkActive();
          if (!_runtimeHost.isCurrentHandle(handle) ||
              handle.session.loginIdentity != identity) {
            throw SourceTaskCancelled(
              request.resourceId,
              SourceTaskStopReason.sourceChanged,
            );
          }
        },
        commit: (write) => request.runCommit(write),
      );
    } catch (error) {
      rethrowSourceOperationStop(error);
      // Optional profile data retains its existing ordinary-error fallback.
    }
    request.checkActive();
    if (!_runtimeHost.isCurrentHandle(handle) ||
        handle.session.loginIdentity != identity) {
      return null;
    }
    return _cachedAvatarUrl(facade);
  });
}

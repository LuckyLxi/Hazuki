import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/source_task.dart';
import '../runtime/source_operation_context.dart';
import '../runtime/source_operation_runner.dart';
import '../runtime/source_shared_request.dart';
import 'source_cloud_reading_session.dart';

import '../../../models/hazuki_models.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_initialization_operations.dart';

/// Optional capability. No cloud position ever enters the local progress DB or
/// the WebDAV participant. This account-scoped cache is for display only.
abstract interface class SourceCloudReadingGateway {
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  });
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  });
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  });
}

abstract interface class SourceCloudReadingEvents implements Listenable {}

class SourceCloudReadingCapability extends ChangeNotifier
    implements SourceCloudReadingGateway, SourceCloudReadingEvents {
  SourceCloudReadingCapability(
    this.host,
    this.operations, {
    this.loadReadRuntime,
  }) {
    host.addListener(_changed);
    host.runtimeRegistry.addListener(_changed);
    scheduleMicrotask(_changed);
  }
  final SourceRuntimeHost host;
  final SourceRuntimeInitializationOperations operations;
  final Future<void> Function(SourceRuntimeHandle)? loadReadRuntime;
  SourceCloudReadingSession? _session;
  SourceSharedRequest<List<ExploreComic>>? _importing;
  final _history = <ExploreComic>[];
  final _closing = <Future<void>>[];
  bool _disposed = false;

  Future<void> get whenSettled => Future.wait(_closing).then((_) {});

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    host.removeListener(_changed);
    host.runtimeRegistry.removeListener(_changed);
    _retire(SourceTaskStopReason.ownerDisposed);
    _history.clear();
    super.dispose();
  }

  void _retire(SourceTaskStopReason reason) {
    final session = _session;
    _session = null;
    _importing = null;
    if (session != null) _closing.add(session.close(reason));
  }

  void _changed() {
    if (_disposed) return;
    final key = host.activeSourceKey;
    final handle = key.isEmpty ? null : host.handleFor(key);
    final identity = handle?.session.loginIdentity;
    final current = _session;
    if (current != null &&
        identical(current.owner, handle) &&
        current.identity == identity) {
      return;
    }
    final reason = current?.owner.sourceKey != key
        ? SourceTaskStopReason.sourceChanged
        : !identical(current?.owner, handle)
        ? SourceTaskStopReason.pluginUpdated
        : SourceTaskStopReason.accountChanged;
    _retire(reason);
    _history.clear();
    if (handle != null) {
      _session = SourceCloudReadingSession(
        host,
        handle,
        identity,
        loadReadRuntime,
      );
    }
    notifyListeners();
    final session = _session;
    if (identity != null && session != null) {
      scheduleMicrotask(() async {
        if (_disposed || !identical(_session, session)) return;
        try {
          await refreshCloudReadingHistory(key);
        } catch (_) {
          /* Reading remains available. */
        }
      });
    }
  }

  SourceTaskOrigin _readOrigin(SourceTaskOrigin? origin) => SourceTaskOrigin(
    ownerId: origin?.ownerId ?? createSourceTaskId(),
    groupId: origin?.groupId ?? createSourceTaskId(),
    requestSequence: origin?.requestSequence ?? 0,
    cancellation: origin?.cancellation,
    resultDisposition: origin?.resultDisposition,
    workTimeout: origin?.workTimeout,
  );

  Future<SourceCloudReadingSession> _ready(
    SourceRuntimeHandle owner,
    SourceOperationContext context,
  ) async {
    final identity = owner.session.loginIdentity;
    final hadSnapshot = owner.session.prefs != null;
    await Future.any([
      operations.ensureSourceInitialized(owner.sourceKey),
      context.task.whenStopped.then((_) => context.checkActive()),
    ]);
    context.checkActive();
    if (_disposed ||
        !host.isCurrentHandle(owner) ||
        owner.sourceKey != host.activeSourceKey ||
        !host.runtimeRegistry.isAllowedSourceKey(owner.sourceKey)) {
      throw const SourceTaskCancelled(
        'cloud.ready',
        SourceTaskStopReason.sourceChanged,
      );
    }
    if (hadSnapshot && identity != owner.session.loginIdentity) {
      throw const SourceTaskCancelled(
        'cloud.ready',
        SourceTaskStopReason.accountChanged,
      );
    }
    // A read never rotates the account's identity by creating a login marker.
    // The real login transaction owns that marker. Legacy credentials already
    // provide loginIdentity, including when two readers become ready together.
    _changed();
    final session = _session!;
    session.checkActive();
    return session;
  }

  Future<T> _read<T>(
    String key,
    String method,
    SourceTaskOrigin? origin,
    Future<T> Function(SourceCloudReadingSession, SourceOperationContext)
    operation,
  ) async {
    if (_disposed ||
        key != host.activeSourceKey ||
        !host.runtimeRegistry.isAllowedSourceKey(key)) {
      throw const SourceTaskCancelled(
        'cloud.read',
        SourceTaskStopReason.sourceChanged,
      );
    }
    final owner = host.handleFor(key);
    SourceCloudReadingSession? session;
    SourceOperationContext? context;
    try {
      return await runSourceOperation(host, owner, method, (task) async {
        context = task;
        session = await _ready(owner, task);
        session!.attach(task);
        return operation(session!, task);
      }, origin: _readOrigin(origin));
    } finally {
      if (session != null && context != null) {
        await session!.release(context!.task);
      }
    }
  }

  bool _declares(SourceRuntimeHandle h, String method) =>
      h.runtime.engine?.cachedValue(
        'typeof globalThis.__hazuki_source.comic?.$method === "function"',
      ) ==
      true;

  bool _mayUseCloudReading(SourceRuntimeHandle handle) =>
      handle.runtime.engine != null
      ? _declares(handle, 'loadReadingProgress')
      : host
                .definitionFor(handle.sourceKey)
                .presentation['__hostCloudReading'] ==
            true;

  @override
  Future<bool> usesCloudReading(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    if (!host.runtimeRegistry.isAllowedSourceKey(sourceKey)) return false;
    final owner = host.handleFor(sourceKey);
    if (!_mayUseCloudReading(owner)) return false;
    return _read(
      sourceKey,
      'cloud.capability',
      taskOrigin,
      (session, context) async =>
          _declares(session.owner, 'loadReadingProgress'),
    );
  }

  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId, {
    SourceTaskOrigin? taskOrigin,
  }) => _read(sourceKey, 'cloud.progress', taskOrigin, (
    session,
    context,
  ) async {
    if (!_declares(session.owner, 'loadReadingProgress')) {
      throw StateError('cloud_reading_not_supported');
    }
    if (session.identity == null) {
      throw StateError('cloud_reading_login_required');
    }
    final raw = await session.invoke(context, 'loadReadingProgress', comicId);
    context.checkActive();
    session.checkActive();
    return raw == null ? null : parseCloudReadingProgress(raw);
  });

  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey, {
    SourceTaskOrigin? taskOrigin,
  }) async {
    if (_disposed ||
        sourceKey != host.activeSourceKey ||
        !host.runtimeRegistry.isAllowedSourceKey(sourceKey)) {
      throw const SourceTaskCancelled(
        'cloud.history',
        SourceTaskStopReason.sourceChanged,
      );
    }
    final owner = host.handleFor(sourceKey);
    if (!_mayUseCloudReading(owner) ||
        (owner.runtime.engine != null &&
            !_declares(owner, 'loadReadingHistory'))) {
      return const [];
    }
    await owner.session.ensurePrefs();
    if (owner.session.loginIdentity == null) return const [];
    return _read(sourceKey, 'cloud.history', taskOrigin, (
      session,
      context,
    ) async {
      if (!_declares(owner, 'loadReadingProgress') ||
          !_declares(owner, 'loadReadingHistory')) {
        return const [];
      }
      var pending = _importing;
      if (pending == null || !pending.available) {
        late final SourceSharedRequest<List<ExploreComic>> created;
        created = SourceSharedRequest<List<ExploreComic>>(
          pluginId: sourceKey,
          method: 'cloud.history.producer',
          drainOperationOnStop: true,
          onUnavailable: () {
            if (identical(_importing, created)) _importing = null;
          },
          operation: (request) async {
            SourceOperationContext? producer;
            try {
              return await runSourceOperation(
                host,
                owner,
                'cloud.history.pages',
                (task) {
                  producer = task;
                  session.attach(task);
                  return _loadHistory(session, task);
                },
                origin: SourceTaskOrigin(
                  ownerId: request.resourceId,
                  groupId: request.resourceId,
                  requestSequence: 0,
                  cancellation: request.cancellation,
                ),
              );
            } finally {
              if (producer != null) await session.release(producer!.task);
            }
          },
        );
        _importing = pending = created;
      }
      try {
        return await pending.subscribe(task: context.task);
      } catch (error) {
        rethrowSourceOperationStop(error);
        session.checkActive();
        context.checkActive();
        return List.unmodifiable(_history);
      }
    });
  }

  Future<List<ExploreComic>> _loadHistory(
    SourceCloudReadingSession session,
    SourceOperationContext context,
  ) async {
    final items = <String, (ExploreComic, int)>{};
    for (var page = 1; ; page++) {
      session.checkActive();
      context.checkActive();
      final raw = await session.invoke(context, 'loadReadingHistory', page);
      session.checkActive();
      context.checkActive();
      if (raw is! Map || raw['items'] is! List) {
        throw const FormatException('cloud_reading_invalid_history');
      }
      final list = raw['items'] as List;
      final max = raw['maxPage'];
      if (max != null && (max is! int || max < 0)) {
        throw const FormatException('cloud_reading_invalid_max_page');
      }
      for (final item in list) {
        if (item is! Map || item['comic'] is! Map) {
          throw const FormatException('cloud_reading_invalid_comic');
        }
        final progress = parseCloudReadingProgress(item['progress']);
        final comic = item['comic'] as Map;
        final id = comic['id']?.toString() ?? '';
        if (id.isEmpty || comic['title'] is! String) {
          throw const FormatException('cloud_reading_invalid_comic');
        }
        items[id] = (
          ExploreComic(
            id: id,
            title: comic['title'] as String,
            subTitle: comic['subTitle']?.toString() ?? '',
            cover: comic['cover']?.toString() ?? '',
            sourceKey: session.owner.sourceKey,
            tags:
                (comic['tags'] as List?)?.map((v) => v.toString()).toList() ??
                const [],
          ),
          progress['updatedAtMs'] as int? ?? 0,
        );
      }
      if (list.isEmpty || (max is int && page >= max)) break;
    }
    final ordered = items.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    session.checkActive();
    context.checkActive();
    _history
      ..clear()
      ..addAll(ordered.map((v) => v.$1));
    return List.unmodifiable(_history);
  }
}

Map<String, dynamic> parseCloudReadingProgress(Object? raw) {
  if (raw is! Map ||
      raw['chapterId'] is! String ||
      (raw['chapterId'] as String).isEmpty ||
      raw['page'] is! int ||
      (raw['page'] as int) < 1) {
    throw const FormatException('cloud_reading_invalid_progress');
  }
  for (final field in ['totalPages', 'updatedAtMs']) {
    if (raw[field] != null &&
        (raw[field] is! int ||
            (raw[field] as int) < (field == 'totalPages' ? 1 : 0))) {
      throw const FormatException('cloud_reading_invalid_progress');
    }
  }
  return {
    'epId': raw['chapterId'],
    'imagePage': raw['page'],
    'cloud': true,
    if (raw['totalPages'] != null) 'totalPages': raw['totalPages'],
    if (raw['updatedAtMs'] != null) 'updatedAtMs': raw['updatedAtMs'],
  };
}

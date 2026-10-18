import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../account/source_login_interaction.dart';
import '../account/source_login_storage_transaction.dart';

import '../../../models/hazuki_models.dart';
import '../runtime/source_runtime_handle.dart';
import '../runtime/source_runtime_host.dart';
import '../runtime/source_runtime_operations.dart';

/// Optional capability. No cloud position ever enters the local progress DB or
/// the WebDAV participant. This account-scoped cache is for display only.
abstract interface class SourceCloudReadingGateway {
  Future<bool> usesCloudReading(String sourceKey);
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId,
  );
  Future<List<ExploreComic>> refreshCloudReadingHistory(String sourceKey);
}

abstract interface class SourceCloudReadingEvents implements Listenable {}

mixin SourceCloudReadingAdapter
    implements SourceCloudReadingGateway, SourceCloudReadingEvents {
  Object get cloudReadingDelegate;
  @override
  void addListener(VoidCallback listener) {
    final delegate = cloudReadingDelegate;
    if (delegate is SourceCloudReadingEvents) delegate.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    final delegate = cloudReadingDelegate;
    if (delegate is SourceCloudReadingEvents) delegate.removeListener(listener);
  }

  @override
  Future<bool> usesCloudReading(String sourceKey) async {
    final delegate = cloudReadingDelegate;
    return delegate is SourceCloudReadingGateway &&
        await delegate.usesCloudReading(sourceKey);
  }

  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId,
  ) async {
    final delegate = cloudReadingDelegate;
    return delegate is SourceCloudReadingGateway
        ? delegate.loadCloudReadingProgress(sourceKey, comicId)
        : null;
  }

  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey,
  ) async {
    final delegate = cloudReadingDelegate;
    return delegate is SourceCloudReadingGateway
        ? delegate.refreshCloudReadingHistory(sourceKey)
        : const [];
  }
}

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
  final SourceRuntimeOperations operations;
  final Future<void> Function(SourceRuntimeHandle)? loadReadRuntime;
  SourceRuntimeHandle? _readerHandle;
  Future<SourceRuntimeHandle>? _readerInitialization;
  SourceLoginStorageTransaction? _readerStorage;
  Completer<void> _cancelSignal = Completer<void>();
  String? _identity;
  String? _source;
  SourceRuntimeHandle? _owner;
  int _generation = 0;
  final _history = <ExploreComic>[];
  Future<List<ExploreComic>>? _importing;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _history.clear();
    _cancelReadRuntime();
    host.removeListener(_changed);
    host.runtimeRegistry.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (_disposed) return;
    final key = host.activeSourceKey;
    final handle = key.isEmpty ? null : host.handleFor(key);
    final identity = handle?.session.loginIdentity;
    if (key == _source && identity == _identity && identical(handle, _owner)) {
      return;
    }
    _source = key;
    _identity = identity;
    _owner = handle;
    _generation++;
    _cancelReadRuntime();
    _history.clear();
    _importing = null;
    notifyListeners();
    if (identity != null) {
      scheduleMicrotask(() async {
        try {
          await refreshCloudReadingHistory(key);
        } catch (_) {
          /* Reading remains available. */
        }
      });
    }
  }

  void _cancelReadRuntime() {
    if (!_cancelSignal.isCompleted) _cancelSignal.complete();
    _cancelSignal = Completer<void>();
    final handle = _readerHandle;
    _readerHandle = null;
    _readerInitialization = null;
    _readerStorage?.discard();
    _readerStorage = null;
    handle?.loginCancellation?.cancel();
    handle?.dio.close(force: true);
    handle?.requestDispose();
  }

  Future<SourceRuntimeHandle> _reader(SourceRuntimeHandle owner) {
    final load = loadReadRuntime;
    if (load == null) return Future.value(owner);
    final pending = _readerInitialization;
    if (pending != null) return pending;
    final generation = _generation;
    final transaction = _readerStorage = SourceLoginStorageTransaction(
      owner.secureStorage,
    );
    final handle = _readerHandle =
        SourceRuntimeHandle(
            sourceKey: owner.sourceKey,
            secureStorage: transaction,
            ensureInitialized: (_) async {},
            notifyRuntimeStateChanged: (_) {},
          )
          ..pluginDirectory = owner.pluginDirectory
          ..loginCancellation = SourceLoginCancellation();
    handle.session
      ..prefs = owner.session.prefs
      ..stagedStore = Map<String, dynamic>.from(
        jsonDecode(jsonEncode(owner.session.loadSourceStore(owner.sourceKey)))
            as Map,
      );
    return _readerInitialization = () async {
      try {
        await load(handle);
        _check(owner, generation);
        return handle;
      } catch (_) {
        if (identical(_readerHandle, handle)) _cancelReadRuntime();
        rethrow;
      }
    }();
  }

  Future<Object?> _invoke(
    SourceRuntimeHandle owner,
    int generation,
    String method,
    Object argument,
  ) async {
    final signal = _cancelSignal.future;
    _check(owner, generation);
    final handle = await _reader(owner);
    _check(owner, generation);
    return Future.any<Object?>([
      handle.facade.js.resolve(
        handle.runtime.engine!.invoke(
          '(value) => globalThis.__hazuki_source.comic.$method(value)',
          [argument],
        ),
      ),
      signal.then((_) => throw StateError('cloud_reading_session_changed')),
    ]);
  }

  Future<SourceRuntimeHandle> _ready(String key) async {
    if (_disposed) throw StateError('cloud_reading_disposed');
    if (!host.runtimeRegistry.isAllowedSourceKey(key) ||
        key != host.activeSourceKey) {
      throw StateError('cloud_reading_source_changed');
    }
    final ownerBeforeInit = host.handleFor(key);
    final hadAccountSnapshot = ownerBeforeInit.session.prefs != null;
    final accountBeforeInit = ownerBeforeInit.session.loginIdentity;
    await operations.ensureSourceInitialized(key);
    if (_disposed ||
        key != host.activeSourceKey ||
        !host.runtimeRegistry.isAllowedSourceKey(key)) {
      throw StateError('cloud_reading_source_changed');
    }
    final session = host.handleFor(key).session;
    if (!host.isCurrentHandle(ownerBeforeInit) ||
        (hadAccountSnapshot && session.loginIdentity != accountBeforeInit)) {
      throw StateError('cloud_reading_session_changed');
    }
    if (session.hasLogin &&
        session.loadSourceData(key, 'login_session') is! String) {
      await session.saveSourceData(
        key,
        'login_session',
        DateTime.now().microsecondsSinceEpoch.toString(),
      );
      host.notifyActiveRuntimeChanged(key);
    }
    _changed();
    return host.handleFor(key);
  }

  bool _declares(SourceRuntimeHandle h, String method) =>
      h.runtime.engine?.evaluate(
        'typeof globalThis.__hazuki_source.comic?.$method === "function"',
      ) ==
      true;

  bool _mayUseCloudReading(SourceRuntimeHandle handle) {
    if (handle.runtime.engine != null) {
      return _declares(handle, 'loadReadingProgress');
    }
    // The inspector derives this hint from the actual function declaration.
    // Legacy catalogs need no network initialization just to retain local mode.
    return host
            .definitionFor(handle.sourceKey)
            .presentation['__hostCloudReading'] ==
        true;
  }

  @override
  Future<bool> usesCloudReading(String sourceKey) async {
    if (!host.runtimeRegistry.isAllowedSourceKey(sourceKey)) return false;
    final handle = host.handleFor(sourceKey);
    if (!_mayUseCloudReading(handle)) return false;
    return _declares(await _ready(sourceKey), 'loadReadingProgress');
  }

  void _check(SourceRuntimeHandle h, int generation) {
    if (generation != _generation ||
        h.isDisposed ||
        !host.isCurrentHandle(h) ||
        h.sourceKey != host.activeSourceKey ||
        h.session.loginIdentity != _identity) {
      throw StateError('cloud_reading_session_changed');
    }
  }

  @override
  Future<Map<String, dynamic>?> loadCloudReadingProgress(
    String sourceKey,
    String comicId,
  ) async {
    final h = await _ready(sourceKey);
    if (!_declares(h, 'loadReadingProgress')) {
      throw StateError('cloud_reading_not_supported');
    }
    if (h.session.loginIdentity == null) {
      throw StateError('cloud_reading_login_required');
    }
    final generation = _generation;
    final raw = await _invoke(h, generation, 'loadReadingProgress', comicId);
    _check(h, generation);
    return raw == null ? null : parseCloudReadingProgress(raw);
  }

  @override
  Future<List<ExploreComic>> refreshCloudReadingHistory(
    String sourceKey,
  ) async {
    if (_disposed) throw StateError('cloud_reading_disposed');
    if (!host.runtimeRegistry.isAllowedSourceKey(sourceKey) ||
        sourceKey != host.activeSourceKey) {
      throw StateError('cloud_reading_source_changed');
    }
    final handle = host.handleFor(sourceKey);
    if (!_mayUseCloudReading(handle) ||
        (handle.runtime.engine != null &&
            !_declares(handle, 'loadReadingHistory'))) {
      return const [];
    }
    await handle.session.ensurePrefs();
    if (handle.session.loginIdentity == null) return const [];
    final h = await _ready(sourceKey);
    if (h.session.loginIdentity == null ||
        !_declares(h, 'loadReadingProgress') ||
        !_declares(h, 'loadReadingHistory')) {
      return const [];
    }
    final pending = _importing;
    if (pending != null) return pending;
    final generation = _generation;
    final work = _loadHistory(h, generation);
    _importing = work;
    try {
      return await work;
    } catch (_) {
      _check(h, generation);
      // Cache is allowed for display, never for position restoration.
      return List.unmodifiable(_history);
    } finally {
      if (identical(_importing, work)) _importing = null;
    }
  }

  Future<List<ExploreComic>> _loadHistory(
    SourceRuntimeHandle h,
    int generation,
  ) async {
    final items = <String, (ExploreComic, int)>{};
    for (var page = 1; ; page++) {
      _check(h, generation);
      final raw = await _invoke(h, generation, 'loadReadingHistory', page);
      _check(h, generation);
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
            sourceKey: h.sourceKey,
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
    _check(h, generation);
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

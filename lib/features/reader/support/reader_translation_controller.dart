import 'dart:async';
import 'dart:collection';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../services/translation/manga_translation_service.dart';
import '../../../services/translation/manga_translation_settings_store.dart';
import '../../../services/translation/models/translation_models.dart';
import '../../../services/translation/translation_failure.dart';
import '../../../services/translation/translation_glossary_store.dart';

enum PageTranslationStatus { idle, queued, translating, done, failed }

class PageTranslationView {
  PageTranslationView({
    this.status = PageTranslationStatus.idle,
    this.result,
    this.failure,
    Set<String> originalRegions = const {},
  }) : originalRegions = Set.unmodifiable(originalRegions);
  final PageTranslationStatus status;
  final PageTranslationResult? result;
  final TranslationFailure? failure;
  final Set<String> originalRegions;
}

class ReaderTranslationController extends ChangeNotifier {
  ReaderTranslationController({
    required MangaTranslationService service,
    required this.settings,
    required this.glossary,
    required Future<Uint8List?> Function(String url) resolveImageBytes,
    required List<String> Function() images,
    required List<int> Function(int index) spreadImageIndices,
    required int Function(int index) spreadStartIndex,
    required int Function() spreadSize,
    required this.sourceKey,
    required this.comicId,
    required void Function(TranslationFailure failure) onFailure,
  }) : _service = service,
       _resolveImageBytes = resolveImageBytes,
       _images = images,
       _spreadImageIndices = spreadImageIndices,
       _spreadStartIndex = spreadStartIndex,
       _spreadSize = spreadSize,
       _onFailure = onFailure {
    settings.addListener(_settingsChanged);
  }

  final MangaTranslationService _service;
  final MangaTranslationSettingsStore settings;
  final TranslationGlossaryStore glossary;
  final Future<Uint8List?> Function(String url) _resolveImageBytes;
  final List<String> Function() _images;
  final List<int> Function(int index) _spreadImageIndices;
  final int Function(int index) _spreadStartIndex;
  final int Function() _spreadSize;
  final String sourceKey, comicId;
  final void Function(TranslationFailure failure) _onFailure;
  final _states = <String, ValueNotifier<PageTranslationView>>{};
  final _queue = Queue<String>();
  final _active = <String, CancelToken>{};
  final _bypass = <String>{};
  Set<String> _window = {}, _visible = {};
  int _index = 0, _failures = 0;
  bool _disposed = false, _tripped = false;

  bool get modeOn =>
      !_tripped &&
      settings.enabled &&
      settings.readerModeOn &&
      settings.isConfigured;
  ValueListenable<PageTranslationView> pageState(String url) => _state(url);
  ValueNotifier<PageTranslationView> _state(String url) =>
      _states.putIfAbsent(url, () => ValueNotifier(PageTranslationView()));

  Future<void> toggleMode() async {
    if (!settings.isConfigured) return;
    _failures = 0;
    _tripped = false;
    await settings.setReaderModeOn(!settings.readerModeOn);
  }

  void _settingsChanged() {
    if (_disposed) return;
    if (modeOn) {
      updateWindow(_index);
    } else {
      _cancelAll();
    }
    notifyListeners();
  }

  void updateWindow(int index) {
    _index = index;
    if (_disposed || !modeOn) return;
    final images = _images();
    final visibleIndices = _spreadImageIndices(index);
    _visible = {
      for (final value in visibleIndices)
        if (value >= 0 && value < images.length) images[value],
    };
    final start = _spreadStartIndex(index) + _spreadSize();
    final ahead = [
      for (
        var value = start;
        value < start + settings.prefetchAhead && value < images.length;
        value++
      )
        if (value >= 0) images[value],
    ];
    _window = {..._visible, ...ahead};
    for (final entry in _active.entries) {
      if (!_window.contains(entry.key)) {
        entry.value.cancel();
        _state(entry.key).value = PageTranslationView();
      }
    }
    for (final url in _queue) {
      if (!_window.contains(url)) _state(url).value = PageTranslationView();
    }
    _queue.clear();
    for (final url in [..._visible, ...ahead]) {
      final status = _state(url).value.status;
      if (_active.containsKey(url) ||
          status == PageTranslationStatus.done ||
          status == PageTranslationStatus.failed ||
          _queue.contains(url)) {
        continue;
      }
      _queue.add(url);
      _state(url).value = PageTranslationView(
        status: PageTranslationStatus.queued,
      );
    }
    _pump();
  }

  void _pump() {
    while (!_disposed && modeOn && _active.length < 2 && _queue.isNotEmpty) {
      final url = _queue.removeFirst();
      final token = CancelToken();
      _active[url] = token;
      final bypassCache = _bypass.remove(url);
      _state(url).value = PageTranslationView(
        status: PageTranslationStatus.translating,
      );
      unawaited(_translate(url, token, bypassCache));
    }
  }

  Future<void> _translate(
    String url,
    CancelToken token,
    bool bypassCache,
  ) async {
    try {
      final bytes = await Future.any<Uint8List?>([
        _resolveImageBytes(url),
        token.whenCancel.then<Uint8List?>(
          (_) =>
              throw const TranslationFailure(TranslationFailureKind.cancelled),
        ),
      ]);
      if (token.isCancelled) return;
      if (bytes == null) {
        throw const TranslationFailure(TranslationFailureKind.badResponse);
      }
      final result = await _service.translatePage(
        imageBytes: bytes,
        sourceKey: sourceKey,
        comicId: comicId,
        bypassCache: bypassCache,
        cancelToken: token,
      );
      if (_disposed || token.isCancelled) return;
      _failures = 0;
      _state(url).value = PageTranslationView(
        status: PageTranslationStatus.done,
        result: result,
      );
    } catch (error) {
      if (_disposed || token.isCancelled) return;
      final failure = TranslationFailure.from(error);
      if (failure.kind == TranslationFailureKind.cancelled) {
        _state(url).value = PageTranslationView();
        return;
      }
      _state(url).value = PageTranslationView(
        status: PageTranslationStatus.failed,
        failure: failure,
      );
      _failures++;
      if (_failures >= 3 ||
          failure.kind == TranslationFailureKind.unauthorized ||
          failure.kind == TranslationFailureKind.quotaExceeded) {
        _tripped = true;
        _cancelAll();
        await settings.setReaderModeOn(false);
        if (!_disposed) _onFailure(failure);
      }
    } finally {
      if (identical(_active[url], token)) _active.remove(url);
      if (!_disposed && modeOn && _window.isNotEmpty) updateWindow(_index);
    }
  }

  void retry(String url) {
    if (_disposed || !modeOn || !_window.contains(url)) return;
    _state(url).value = PageTranslationView();
    updateWindow(_index);
  }

  void retranslateVisible() {
    if (_disposed || !modeOn) return;
    for (final url in _visible) {
      _active[url]?.cancel();
      _bypass.add(url);
      _state(url).value = PageTranslationView();
    }
    updateWindow(_index);
  }

  void toggleRegion(String url, String regionId) {
    if (_disposed) return;
    final state = _state(url);
    final current = state.value;
    if (current.result == null ||
        !current.result!.regions.any((region) => region.id == regionId)) {
      return;
    }
    final originals = {...current.originalRegions};
    if (!originals.add(regionId)) originals.remove(regionId);
    state.value = PageTranslationView(
      status: current.status,
      result: current.result,
      originalRegions: originals,
    );
  }

  void _cancelAll() {
    _queue.clear();
    _window.clear();
    _visible.clear();
    _bypass.clear();
    for (final token in _active.values) {
      token.cancel();
    }
    for (final state in _states.values) {
      if (state.value.status == PageTranslationStatus.queued ||
          state.value.status == PageTranslationStatus.translating) {
        state.value = PageTranslationView();
      }
    }
  }

  void reset() {
    _cancelAll();
    _failures = 0;
    for (final state in _states.values) {
      state.value = PageTranslationView();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    settings.removeListener(_settingsChanged);
    _cancelAll();
    for (final state in _states.values) {
      state.dispose();
    }
    super.dispose();
  }
}

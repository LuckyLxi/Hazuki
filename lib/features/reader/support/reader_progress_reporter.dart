import 'dart:async';

/// Coalesces observed viewport positions, independently of image loading.
class ReaderProgressReporter {
  ReaderProgressReporter({
    required this.comicId,
    required this.chapterId,
    required this.send,
    this.interval = const Duration(seconds: 5),
  });

  final String comicId;
  final String chapterId;
  final Future<void> Function(Map<String, Object> progress) send;
  final Duration interval;
  Map<String, Object>? _latest;
  Timer? _timer;
  bool _sent = false;
  bool _closed = false;

  void observe({
    required int firstImage,
    required int lastImage,
    required int totalPages,
  }) {
    if (_closed ||
        totalPages <= 0 ||
        firstImage < 0 ||
        firstImage >= totalPages) {
      return;
    }
    final next = <String, Object>{
      'comicId': comicId,
      'chapterId': chapterId,
      'page': firstImage + 1,
      'totalPages': totalPages,
      'visiblePages': <int>[
        for (var i = firstImage; i <= lastImage && i < totalPages; i++) i + 1,
      ],
    };
    if (_latest?['page'] == next['page'] &&
        _latest?['totalPages'] == totalPages &&
        (_latest?['visiblePages'] as List<int>?)?.last ==
            (next['visiblePages'] as List<int>).last) {
      return;
    }
    _latest = next;
    if (!_sent) {
      _sent = true;
      _emit('initial');
      _timer = Timer(interval, _tick);
    } else {
      _dirty = true;
      _timer ??= Timer(interval, _tick);
    }
  }

  bool _dirty = false;
  void _tick() {
    _timer = null;
    if (_dirty && !_closed) {
      _dirty = false;
      _emit('page');
      _timer = Timer(interval, _tick);
    }
  }

  void flush(String reason) {
    if (_latest == null || _closed) return;
    _dirty = false;
    _emit(reason);
  }

  void close(String reason) {
    if (_closed) return;
    flush(reason);
    _closed = true;
    _timer?.cancel();
  }

  void _emit(String reason) {
    final snapshot = Map<String, Object>.unmodifiable({
      ..._latest!,
      'reason': reason,
    });
    unawaited(
      Future<void>.sync(() => send(snapshot)).catchError((Object _) {}),
    );
  }
}

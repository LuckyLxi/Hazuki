import 'package:flutter/material.dart';

class ReaderDiagnosticsState {
  int lastLoggedVisiblePageIndex = -1;
  int readerDiagnosticSequence = 0;
  DateTime? lastUnexpectedListJumpLoggedAt;

  bool shouldLogUnexpectedListJump() {
    final now = DateTime.now();
    final lastLoggedAt = lastUnexpectedListJumpLoggedAt;
    if (lastLoggedAt != null &&
        now.difference(lastLoggedAt) < const Duration(milliseconds: 900)) {
      return false;
    }
    lastUnexpectedListJumpLoggedAt = now;
    return true;
  }

  int nextDiagnosticSequence() => ++readerDiagnosticSequence;
}

double normalizeReaderLogDouble(num value) {
  final normalized = value.toDouble();
  if (!normalized.isFinite) {
    return 0;
  }
  return double.parse(normalized.toStringAsFixed(2));
}

List<Map<String, dynamic>> captureReaderRenderedItemsAround({
  required int itemCount,
  required List<GlobalKey> itemKeys,
  required int anchorIndex,
}) {
  if (itemCount <= 0 || itemKeys.isEmpty) {
    return const <Map<String, dynamic>>[];
  }
  final target = anchorIndex.clamp(0, itemCount - 1);
  final start = (target - 2).clamp(0, itemCount - 1);
  final end = (target + 2).clamp(0, itemCount - 1);
  final items = <Map<String, dynamic>>[];
  for (var i = start; i <= end; i++) {
    if (i >= itemKeys.length) {
      continue;
    }
    final ctx = itemKeys[i].currentContext;
    if (ctx == null) {
      items.add({'index': i, 'mounted': false});
      continue;
    }
    final renderObject = ctx.findRenderObject();
    if (renderObject is! RenderBox || !renderObject.hasSize) {
      items.add({'index': i, 'mounted': true, 'hasSize': false});
      continue;
    }
    final top = renderObject.localToGlobal(Offset.zero).dy;
    final height = renderObject.size.height;
    items.add({
      'index': i,
      'mounted': true,
      'top': normalizeReaderLogDouble(top),
      'height': normalizeReaderLogDouble(height),
      'bottom': normalizeReaderLogDouble(top + height),
    });
  }
  return items;
}

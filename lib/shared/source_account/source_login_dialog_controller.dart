import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/account/source_login_interaction.dart';

/// Presents login steps inside the existing dialog route.
class SourceLoginDialogController extends ValueNotifier<Widget?> {
  SourceLoginDialogController() : super(null);

  SourceLoginCancellation? _cancellation;
  bool _disposed = false;

  void cancel() => _cancellation?.cancel();

  Future<Object?> present(
    Widget Function(ValueChanged<Object?> finish) builder,
    SourceLoginCancellation cancellation,
  ) async {
    cancellation.check();
    if (_disposed) throw const SourceLoginCancelled();
    if (_cancellation != null) {
      throw StateError('A login interaction is already active');
    }
    final result = Completer<Object?>();
    void finish(Object? answer) {
      if (!result.isCompleted) result.complete(answer);
    }

    final step = KeyedSubtree(key: UniqueKey(), child: builder(finish));
    _cancellation = cancellation;
    value = step;
    try {
      final answer = await Future.any<Object?>([
        result.future,
        cancellation.whenCancelled.then((_) => null),
      ]);
      if (answer == null) cancellation.cancel();
      cancellation.check();
      return answer;
    } finally {
      _cancellation = null;
      if (!_disposed && identical(value, step)) value = null;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
    super.dispose();
  }
}

/// Shares step layout between standalone prompts and the unified login dialog.
class SourceLoginStepContent extends StatelessWidget {
  const SourceLoginStepContent({
    super.key,
    required this.embedded,
    required this.backgroundColor,
    required this.title,
    required this.content,
    required this.actions,
    this.width = 320,
  });

  final bool embedded;
  final Color backgroundColor;
  final Widget title;
  final Widget content;
  final List<Widget> actions;
  final double width;

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return AlertDialog(
        backgroundColor: backgroundColor,
        title: title,
        content: content,
        actions: actions,
      );
    }
    return SizedBox(
      width: width,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DefaultTextStyle(
              style: Theme.of(context).textTheme.headlineSmall!,
              child: title,
            ),
            const SizedBox(height: 20),
            Flexible(child: content),
            const SizedBox(height: 24),
            OverflowBar(
              spacing: 8,
              alignment: MainAxisAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}

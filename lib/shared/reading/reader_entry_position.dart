import 'package:flutter/widgets.dart';

/// A one-shot entry intent, kept outside chapter switching and route animations.
class ReaderEntryPosition extends InheritedWidget {
  const ReaderEntryPosition({
    super.key,
    required this.progress,
    required super.child,
  });
  final Map<String, dynamic>? progress;
  static Map<String, dynamic>? of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ReaderEntryPosition>()
      ?.progress;
  @override
  bool updateShouldNotify(ReaderEntryPosition oldWidget) => false;
}

import 'package:flutter/widgets.dart';
import 'package:hazuki/models/hazuki_models.dart';

typedef WindowsComicDetailPanelBuilder =
    Widget Function(
      ExploreComic comic,
      String heroTag, {
      required bool shouldAnimatePanelReveal,
      required bool isRestoringPreviousDetail,
      required int initialTabIndex,
      required bool showHomeAction,
      required VoidCallback onBackRequested,
      required VoidCallback onHomeRequested,
    });

/// Supplies detail presentation to every route without storing widgets in the
/// navigation controller. Place above the application's Navigator.
class WindowsComicDetailPresentationScope extends InheritedWidget {
  const WindowsComicDetailPresentationScope({
    super.key,
    required this.panelBuilder,
    required super.child,
  });

  final WindowsComicDetailPanelBuilder panelBuilder;

  static WindowsComicDetailPanelBuilder? maybeOf(
    BuildContext context,
  ) => context
      .dependOnInheritedWidgetOfExactType<WindowsComicDetailPresentationScope>()
      ?.panelBuilder;

  @override
  bool updateShouldNotify(WindowsComicDetailPresentationScope oldWidget) =>
      panelBuilder != oldWidget.panelBuilder;
}

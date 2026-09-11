import 'package:flutter/material.dart';

import 'package:hazuki/l10n/l10n.dart';
import 'package:hazuki/shared/window/windows_app_bar_drag_area.dart';

import 'comic_detail_view_primitives.dart';

class ComicDetailScrollAwareAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const ComicDetailScrollAwareAppBar({
    super.key,
    required this.collapsedTitleListenable,
    required this.appBarComicTitle,
    required this.appBarUpdateTime,
    required this.theme,
    required this.isDesktopPanel,
    required this.onCloseRequested,
    required this.showHomeAction,
    required this.onHomeRequested,
  });

  final ValueNotifier<bool> collapsedTitleListenable;
  final String appBarComicTitle;
  final String appBarUpdateTime;
  final ThemeData theme;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;
  final bool showHomeAction;
  final VoidCallback? onHomeRequested;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !isDesktopPanel,
      leadingWidth: isDesktopPanel && showHomeAction ? 96 : null,
      leading: isDesktopPanel
          ? Row(
              children: [
                IconButton(
                  tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                  onPressed: onCloseRequested,
                  icon: const Icon(Icons.arrow_back),
                ),
                if (showHomeAction)
                  IconButton(
                    tooltip: l10n(context).comicDetailBackToHome,
                    onPressed: onHomeRequested,
                    icon: const Icon(Icons.home_outlined),
                  ),
              ],
            )
          : null,
      titleSpacing: 0,
      title: ValueListenableBuilder<bool>(
        valueListenable: collapsedTitleListenable,
        builder: (context, showCollapsedComicTitle, _) {
          return ComicDetailAppBarTitle(
            showCollapsedComicTitle: showCollapsedComicTitle,
            appBarComicTitle: appBarComicTitle,
            appBarUpdateTime: appBarUpdateTime,
            theme: theme,
          );
        },
      ),
      actions: const [HazukiWindowsCaptionButtonSpacer()],
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: const HazukiWindowsAppBarDragArea(
        child: SizedBox.expand(),
      ),
    );
  }
}

class ComicDetailTopSurfaceOverlay extends StatelessWidget {
  const ComicDetailTopSurfaceOverlay({
    super.key,
    required this.progressListenable,
    required this.surface,
    required this.height,
  });

  final ValueNotifier<double> progressListenable;
  final Color surface;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: height,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: progressListenable,
          builder: (context, alpha, _) {
            final targetAlpha = alpha.clamp(0.0, 1.0);
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: targetAlpha),
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              builder: (context, animatedAlpha, _) {
                if (animatedAlpha <= 0.001) {
                  return const SizedBox.expand();
                }
                return ColoredBox(
                  color: surface.withValues(alpha: animatedAlpha),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

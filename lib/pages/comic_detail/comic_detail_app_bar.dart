part of '../comic_detail_page.dart';

class _ComicDetailScrollAwareAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ComicDetailScrollAwareAppBar({
    required this.collapsedTitleListenable,
    required this.appBarComicTitle,
    required this.appBarUpdateTime,
    required this.theme,
    required this.isDesktopPanel,
    required this.onCloseRequested,
  });

  final ValueNotifier<bool> collapsedTitleListenable;
  final String appBarComicTitle;
  final String appBarUpdateTime;
  final ThemeData theme;
  final bool isDesktopPanel;
  final VoidCallback? onCloseRequested;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: !isDesktopPanel,
      leading: isDesktopPanel
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              onPressed: onCloseRequested,
              icon: const Icon(Icons.close),
            )
          : null,
      titleSpacing: 0,
      title: ValueListenableBuilder<bool>(
        valueListenable: collapsedTitleListenable,
        builder: (context, showCollapsedComicTitle, _) {
          return _ComicDetailAppBarTitle(
            showCollapsedComicTitle: showCollapsedComicTitle,
            appBarComicTitle: appBarComicTitle,
            appBarUpdateTime: appBarUpdateTime,
            theme: theme,
          );
        },
      ),
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }
}

class _ComicDetailTopSurfaceOverlay extends StatelessWidget {
  const _ComicDetailTopSurfaceOverlay({
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
            if (alpha <= 0) {
              return const SizedBox.expand();
            }
            return ColoredBox(color: surface.withValues(alpha: alpha));
          },
        ),
      ),
    );
  }
}

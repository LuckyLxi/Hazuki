part of '../comic_detail_page.dart';

class _ComicDetailScrollState {
  const _ComicDetailScrollState({
    this.appBarSolidProgress = 0,
    this.showCollapsedComicTitle = false,
  });

  final double appBarSolidProgress;
  final bool showCollapsedComicTitle;

  _ComicDetailScrollState copyWith({
    double? appBarSolidProgress,
    bool? showCollapsedComicTitle,
  }) {
    return _ComicDetailScrollState(
      appBarSolidProgress: appBarSolidProgress ?? this.appBarSolidProgress,
      showCollapsedComicTitle:
          showCollapsedComicTitle ?? this.showCollapsedComicTitle,
    );
  }
}

class _ComicDetailScrollAwareAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _ComicDetailScrollAwareAppBar({
    required this.scrollListenable,
    required this.appBarComicTitle,
    required this.appBarUpdateTime,
    required this.theme,
    required this.surface,
  });

  final ValueNotifier<_ComicDetailScrollState> scrollListenable;
  final String appBarComicTitle;
  final String appBarUpdateTime;
  final ThemeData theme;
  final Color surface;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<_ComicDetailScrollState>(
      valueListenable: scrollListenable,
      builder: (context, scrollState, _) {
        return AppBar(
          titleSpacing: 0,
          title: _ComicDetailAppBarTitle(
            showCollapsedComicTitle: scrollState.showCollapsedComicTitle,
            appBarComicTitle: appBarComicTitle,
            appBarUpdateTime: appBarUpdateTime,
            theme: theme,
          ),
          backgroundColor: Color.lerp(
            Colors.transparent,
            surface,
            scrollState.appBarSolidProgress,
          ),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
        );
      },
    );
  }
}

class _ComicDetailTopSurfaceOverlay extends StatelessWidget {
  const _ComicDetailTopSurfaceOverlay({
    required this.scrollListenable,
    required this.surface,
  });

  final ValueNotifier<_ComicDetailScrollState> scrollListenable;
  final Color surface;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ValueListenableBuilder<_ComicDetailScrollState>(
          valueListenable: scrollListenable,
          builder: (context, scrollState, _) {
            final alpha = scrollState.appBarSolidProgress;
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

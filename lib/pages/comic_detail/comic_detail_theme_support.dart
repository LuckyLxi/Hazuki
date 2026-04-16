part of '../comic_detail_page.dart';

extension _ComicDetailThemeSupportExtension on _ComicDetailPageState {
  ThemeData _buildDetailTheme(ThemeData baseTheme) {
    var theme = baseTheme;
    if (!_comicDynamicColorEnabled) {
      return theme;
    }
    var scheme = theme.brightness == Brightness.light
        ? _lightComicScheme
        : _darkComicScheme;
    if (scheme == null) {
      return theme;
    }
    if (theme.brightness == Brightness.dark &&
        theme.scaffoldBackgroundColor == Colors.black) {
      scheme = scheme.copyWith(
        surface: Colors.black,
        surfaceContainer: Colors.black,
        surfaceContainerLow: Colors.black,
        surfaceContainerLowest: Colors.black,
        surfaceContainerHigh: Colors.black,
        surfaceContainerHighest: Colors.black,
      );
      return theme.copyWith(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        cardColor: Colors.black,
        colorScheme: scheme,
        textSelectionTheme: TextSelectionThemeData(
          selectionColor: scheme.primary.withValues(alpha: 0.38),
          selectionHandleColor: scheme.primary,
          cursorColor: scheme.primary,
        ),
      );
    }
    return theme.copyWith(
      colorScheme: scheme,
      textSelectionTheme: TextSelectionThemeData(
        selectionColor: scheme.primary.withValues(alpha: 0.38),
        selectionHandleColor: scheme.primary,
        cursorColor: scheme.primary,
      ),
    );
  }
}

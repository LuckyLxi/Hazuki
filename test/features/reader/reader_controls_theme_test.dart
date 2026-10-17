import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/features/reader/view/reader_page_indicator_overlay.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final glassEnabled in [false, true]) {
    testWidgets('all reader controls follow theme, glass=$glassEnabled', (
      tester,
    ) async {
      await tester.runAsync(
        () => HazukiLiquidGlass.initialize(enabled: glassEnabled),
      );
      final mode = ValueNotifier(ThemeMode.light);
      addTearDown(mode.dispose);
      final state = ReaderRuntimeState()
        ..applyImages(['1', '2', '3', '4'])
        ..setControlsVisible(true)
        ..setZoomed(true)
        ..updateSettings(pageIndicator: true, pinchToZoom: true);
      addTearDown(state.dispose);
      final light = ThemeData(colorSchemeSeed: Colors.teal);
      final dark = ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.teal,
      );
      late StateSetter updateHost;
      var loading = false;
      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: ValueListenableBuilder<ThemeMode>(
            valueListenable: mode,
            builder: (context, themeMode, _) => MaterialApp(
              theme: light,
              darkTheme: dark,
              themeMode: themeMode,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    updateHost = setState;
                    return ReaderOverlayHost(
                      runtimeState: state,
                      readerTheme: Theme.of(context),
                      title: 'Comic title',
                      chapterIndex: 0,
                      chapterPanelLoading: loading,
                      updateState: setState,
                      goToPage: (_) async {},
                      onBackPressed: () {},
                      onOpenSettingsDrawer: () {},
                      onOpenChaptersPanel: () async {},
                      onPreviousChapter: () {},
                      onNextChapter: () {},
                      onFavorite: () {},
                      onComments: () {},
                      onResetZoom: () {},
                      child: const SizedBox.expand(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      for (final themeMode in [
        ThemeMode.light,
        ThemeMode.dark,
        ThemeMode.light,
      ]) {
        mode.value = themeMode;
        updateHost(() => state.setControlsVisible(true));
        await tester.pumpAndSettle();
        final theme = themeMode == ThemeMode.dark ? dark : light;
        final foreground = glassEnabled
            ? theme.colorScheme.onSurface
            : Colors.white;
        final glassSurfaces = tester.widgetList<GlassContainer>(
          find.byType(GlassContainer),
        );
        if (glassEnabled) {
          // Top bar, bottom bar, page badge and floating reset surface must all
          // share the same theme material, including while animated off-screen.
          expect(glassSurfaces.length, greaterThanOrEqualTo(3));
          for (final surface in glassSurfaces) {
            expect(
              surface.settings!.glassColor,
              theme.colorScheme.surfaceContainer.withValues(alpha: 0.16),
            );
          }
        } else {
          expect(glassSurfaces, isEmpty);
        }

        expect(
          tester.widget<Text>(find.text('Comic title')).style!.color,
          foreground,
        );
        for (final icon in [
          Icons.arrow_back_rounded,
          Icons.tune_rounded,
          Icons.skip_previous_rounded,
          Icons.skip_next_rounded,
          Icons.favorite_border_rounded,
          Icons.mode_comment_outlined,
          Icons.zoom_out_map_rounded,
        ]) {
          final icons = tester.widgetList<Icon>(find.byIcon(icon));
          expect(icons, isNotEmpty);
          for (final widget in icons) {
            expect(widget.color, foreground);
          }
        }
        final badge = find.descendant(
          of: find.byType(ReaderPageIndicatorOverlay),
          matching: find.byType(Text),
        );
        expect(tester.widget<Text>(badge).style!.color, foreground);
        final sliderTheme = SliderTheme.of(tester.element(find.byType(Slider)));
        expect(
          sliderTheme.inactiveTrackColor,
          foreground.withValues(alpha: 0.18),
        );

        updateHost(() => loading = true);
        await tester.pump();
        final spinner = tester.widget<CircularProgressIndicator>(
          find.byType(CircularProgressIndicator),
        );
        expect(spinner.valueColor!.value, foreground);
        updateHost(() {
          loading = false;
          state.setControlsVisible(false);
        });
        await tester.pumpAndSettle();
        final floatingReset = find.byKey(
          const ValueKey('reader_floating_reset_zoom_button'),
        );
        final resetIcon = find.descendant(
          of: floatingReset,
          matching: find.byIcon(Icons.zoom_out_map_rounded),
        );
        expect(tester.widget<Icon>(resetIcon).color, foreground);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

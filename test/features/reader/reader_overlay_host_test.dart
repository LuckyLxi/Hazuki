import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/reader/state/reader_runtime_state.dart';
import 'package:hazuki/features/reader/view/reader_overlay_host.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final glassEnabled in [false, true]) {
    testWidgets(
      'reader content and controls accept taps, glass=$glassEnabled',
      (tester) async {
        await tester.runAsync(
          () => HazukiLiquidGlass.initialize(enabled: glassEnabled),
        );
        final runtimeState = ReaderRuntimeState()
          ..applyImages(['page-1', 'page-2'])
          ..setControlsVisible(true);
        addTearDown(runtimeState.dispose);
        var pageTaps = 0;
        var backTaps = 0;
        var settingsTaps = 0;
        late StateSetter updateHost;

        await tester.pumpWidget(
          HazukiLiquidGlass.wrap(
            child: MaterialApp(
              theme: ThemeData.dark(),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: StatefulBuilder(
                  builder: (context, setState) {
                    updateHost = setState;
                    return ReaderOverlayHost(
                      runtimeState: runtimeState,
                      readerTheme: Theme.of(context),
                      title: 'Comic title',
                      chapterIndex: 0,
                      chapterPanelLoading: false,
                      updateState: setState,
                      goToPage: (_) async {},
                      onBackPressed: () => backTaps++,
                      onOpenSettingsDrawer: () => settingsTaps++,
                      onResetZoom: () {},
                      child: GestureDetector(
                        key: const ValueKey('comic-page'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () => pageTaps++,
                        child: const SizedBox.expand(),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(GlassScaffold),
          glassEnabled ? findsOneWidget : findsNothing,
        );
        await tester.tap(find.byIcon(Icons.arrow_back_rounded));
        await tester.tap(find.byIcon(Icons.tune_rounded));
        expect(backTaps, 1);
        expect(settingsTaps, 1);
        expect(pageTaps, 0);

        await tester.tap(find.byKey(const ValueKey('comic-page')));
        expect(pageTaps, 1);
        updateHost(() => runtimeState.setControlsVisible(false));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(40, 40));
        expect(pageTaps, 2);
        expect(backTaps, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

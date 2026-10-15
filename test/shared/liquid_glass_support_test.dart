import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/reader/view/reader_control_surface.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';

void main() {
  for (final initiallyEnabled in [false, true]) {
    testWidgets('glass toggle preserves navigation and page state, '
        'initiallyEnabled=$initiallyEnabled', (tester) async {
      await tester.runAsync(
        () => HazukiLiquidGlass.initialize(enabled: initiallyEnabled),
      );
      addTearDown(() => HazukiLiquidGlass.setEnabled(false));

      await tester.pumpWidget(
        HazukiLiquidGlass.wrap(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) {
                          var count = 0;
                          return Scaffold(
                            body: StatefulBuilder(
                              builder: (context, setState) => Column(
                                children: [
                                  TextButton(
                                    onPressed: () => setState(() => count++),
                                    child: Text('Settings count: $count'),
                                  ),
                                  ListenableBuilder(
                                    listenable: HazukiLiquidGlass.changes,
                                    builder: (context, _) =>
                                        ReaderControlSurface(
                                          key: ValueKey(
                                            HazukiLiquidGlass.isAvailable,
                                          ),
                                          borderRadius: 24,
                                          fallbackColor: Colors.black54,
                                          child: const Text('Reader controls'),
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                  child: const Text('Open settings'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings count: 0'));
      await tester.pump();
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));

      for (final enabled in [
        !initiallyEnabled,
        initiallyEnabled,
        !initiallyEnabled,
      ]) {
        await tester.runAsync(() => HazukiLiquidGlass.setEnabled(enabled));
        await tester.pumpAndSettle();

        expect(
          tester.state<NavigatorState>(find.byType(Navigator)),
          same(navigator),
        );
        expect(find.text('Settings count: 1'), findsOneWidget);
        expect(navigator.canPop(), isTrue);
        expect(HazukiLiquidGlass.isAvailable, enabled);
        expect(
          find.byType(GlassContainer),
          enabled ? findsOneWidget : findsNothing,
        );
        expect(tester.takeException(), isNull);
      }
    });
  }
}

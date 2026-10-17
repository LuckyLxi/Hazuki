import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'package:hazuki/features/search/view/search_bar_shell.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/search_box_outline.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final compact in [false, true]) {
      testWidgets('glass toggle preserves editing in $brightness, '
          'compact=$compact', (tester) async {
        await tester.runAsync(
          () => HazukiLiquidGlass.initialize(enabled: false),
        );
        addTearDown(() => HazukiLiquidGlass.setEnabled(false));
        final controller = TextEditingController();
        final focusNode = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focusNode.dispose);
        final submissions = <String>[];
        var tapCount = 0;
        const shellKey = ValueKey('search-shell');
        await tester.pumpWidget(
          HazukiLiquidGlass.wrap(
            child: MaterialApp(
              theme: ThemeData(brightness: brightness),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Center(
                  child: SizedBox(
                    width: 320,
                    child: ListenableBuilder(
                      listenable: controller,
                      builder: (context, _) => SearchBarShell(
                        key: shellKey,
                        controller: controller,
                        focusNode: focusNode,
                        clearKey: 'clear',
                        submitKey: 'submit',
                        compact: compact,
                        onClear: controller.clear,
                        onSubmit: () => submissions.add(controller.text),
                        onTap: () => tapCount++,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shell = find.byKey(shellKey);
        final originalSize = tester.getSize(shell);
        expect(originalSize, Size(320, compact ? 40 : 56));
        expect(focusNode.hasFocus, isFalse);

        await tester.tap(find.byType(TextField));
        await tester.enterText(find.byType(TextField), 'Hazuki');
        controller.value = const TextEditingValue(
          text: 'Hazuki',
          selection: TextSelection(baseOffset: 1, extentOffset: 4),
          composing: TextRange(start: 0, end: 6),
        );
        await tester.pumpAndSettle();
        final editingValue = controller.value;
        final editableState = tester.state<EditableTextState>(
          find.byType(EditableText),
        );
        expect(tapCount, 1);

        final glass = find.byKey(
          const ValueKey('search-bar-liquid-glass-surface'),
        );
        for (final enabled in [true, false, true, false]) {
          await tester.runAsync(() => HazukiLiquidGlass.setEnabled(enabled));
          await tester.pumpAndSettle();
          expect(glass, enabled ? findsOneWidget : findsNothing);
          expect(tester.getSize(shell), originalSize);
          expect(
            tester.state<EditableTextState>(find.byType(EditableText)),
            same(editableState),
          );
          expect(controller.value, editingValue);
          expect(focusNode.hasFocus, isTrue);
          expect(tester.testTextInput.isVisible, isTrue);

          final bar = tester.widget<SearchBar>(find.byType(SearchBar));
          expect(
            bar.backgroundColor!.resolve({WidgetState.focused}),
            enabled
                ? Colors.transparent
                : hazukiSearchBoxBackgroundColor(
                    tester.element(shell),
                    focusProgress: 1,
                  ),
          );
          if (enabled) {
            final container = tester.widget<GlassContainer>(glass);
            expect(container.quality, HazukiLiquidGlass.navigationQuality);
            expect(
              container.settings,
              HazukiLiquidGlass.navigationSettings(tester.element(glass)),
            );
            expect(tester.getSize(glass), originalSize);
          }
        }

        await tester.tap(find.byKey(const ValueKey('clear')));
        await tester.pumpAndSettle();
        expect(controller.text, isEmpty);
        await tester.tap(find.byKey(const ValueKey('submit')));
        expect(submissions, ['']);
        await tester.enterText(find.byType(TextField), 'Action');
        await tester.testTextInput.receiveAction(TextInputAction.search);
        expect(submissions, ['', 'Action']);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}

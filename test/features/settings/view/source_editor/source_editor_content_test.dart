import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/settings/view/source_editor/source_editor_content.dart';
import 'package:hazuki/l10n/app_localizations.dart';
import 'package:re_editor/re_editor.dart';

Finder menuItems() => find.byWidgetPredicate(
  (widget) => widget is PopupMenuItem<void>,
  skipOffstage: false,
);

Future<void> pumpEditor(
  WidgetTester tester,
  CodeLineEditingController controller,
) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: SourceEditorContent(
            strings: AppLocalizations.of(context)!,
            controller: controller,
            saving: false,
            inlineErrorText: null,
            onSaveRequested: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> selectWord(WidgetTester tester) async {
  final editor = tester.getRect(find.byType(CodeEditor));
  final gesture = await tester.startGesture(
    editor.topLeft + const Offset(90, 20),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('long press selects without opening a closed keyboard', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText('const example = 1;');
    addTearDown(controller.dispose);
    await pumpEditor(tester, controller);
    expect(tester.testTextInput.isVisible, isFalse);

    await selectWord(tester);
    expect(controller.selectedText, 'const');
    expect(menuItems(), findsNWidgets(4));
    expect(tester.testTextInput.isVisible, isFalse);

    // A normal tap must still open the keyboard for editing.
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    final rect = tester.getRect(find.byType(CodeEditor));
    await tester.tapAt(rect.topLeft + const Offset(90, 20));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    // Closing the keyboard leaves editor focus intact on Android.
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await selectWord(tester);
    expect(controller.selectedText, 'const');
    expect(tester.testTextInput.isVisible, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('long press preserves an already open keyboard', (tester) async {
    final controller = CodeLineEditingController.fromText('const example = 1;');
    addTearDown(controller.dispose);
    await pumpEditor(tester, controller);
    final rect = tester.getRect(find.byType(CodeEditor));
    await tester.tapAt(rect.topLeft + const Offset(90, 20));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await selectWord(tester);
    expect(controller.selectedText, 'const');
    expect(menuItems(), findsNWidgets(4));
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets(
    'tap, scroll and cancelled press do not trigger long press feedback',
    (tester) async {
      var hapticCount = 0;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            hapticCount++;
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      final controller = CodeLineEditingController.fromText(
        List.generate(100, (i) => 'const example$i = $i;').join('\n'),
      );
      addTearDown(controller.dispose);
      await pumpEditor(tester, controller);
      final rect = tester.getRect(find.byType(CodeEditor));
      await tester.tapAt(rect.topLeft + const Offset(90, 20));
      await tester.pump(const Duration(milliseconds: 600));
      final cancelled = await tester.startGesture(
        rect.topLeft + const Offset(90, 20),
      );
      await tester.pump(const Duration(milliseconds: 200));
      await cancelled.cancel();
      await tester.pump(const Duration(milliseconds: 600));
      final drag = await tester.startGesture(
        rect.centerRight - const Offset(30, 0),
      );
      await drag.moveBy(const Offset(0, -100));
      await tester.pump(const Duration(milliseconds: 600));
      await drag.up();
      await tester.pumpAndSettle();
      expect(hapticCount, 0);
      expect(menuItems(), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('Android long press keeps the source text selected', (
    tester,
  ) async {
    String? copiedText;
    final hapticCalls = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        if (call.method == 'HapticFeedback.vibrate') {
          hapticCalls.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = CodeLineEditingController.fromText('const example = 1;');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: SourceEditorContent(
              strings: AppLocalizations.of(context)!,
              controller: controller,
              saving: false,
              inlineErrorText: null,
              onSaveRequested: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.getRect(find.byType(CodeEditor));
    final position = editor.topLeft + const Offset(90, 20);
    final gesture = await tester.startGesture(position);
    await tester.pump(const Duration(milliseconds: 600));
    expect(controller.selection.isCollapsed, isFalse);
    expect(hapticCalls, <Object?>[null]);
    final selection = controller.selection;
    await gesture.up();
    await tester.pumpAndSettle();
    expect(menuItems(), findsNWidgets(4));
    expect(controller.selection, selection);
    expect(controller.selectedText, 'const');
    // Repeated toolbar requests must replace the existing menu overlay.
    final codeEditor = tester.widget<CodeEditor>(find.byType(CodeEditor));
    final editorContext = tester.element(find.byType(CodeEditor));
    final visibility = ValueNotifier(true);
    addTearDown(visibility.dispose);
    void showToolbar() {
      codeEditor.toolbarController!.show(
        context: editorContext,
        controller: controller,
        anchors: const TextSelectionToolbarAnchors(
          primaryAnchor: Offset(-10000, -10000),
          secondaryAnchor: Offset(200, 200),
        ),
        layerLink: LayerLink(),
        visibility: visibility,
      );
    }

    showToolbar();
    showToolbar();
    await tester.pumpAndSettle();
    expect(menuItems(), findsNWidgets(4));
    expect(tester.getTopLeft(find.text('Copy')).dx, greaterThan(100));
    expect(hapticCalls, <Object?>[null]);
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(copiedText, 'const');
    expect(controller.selection.isCollapsed, isTrue);
    controller.selection = selection;
    showToolbar();
    await tester.pumpAndSettle();
    codeEditor.toolbarController!.hide(editorContext);
    await tester.pumpAndSettle();
    expect(menuItems(), findsNothing);
    expect(find.byType(SourceEditorContent), findsOneWidget);
    showToolbar();
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('outside tap and back dismiss the menu and clear selection', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText('const example = 1;');
    addTearDown(controller.dispose);
    await pumpEditor(tester, controller);
    await selectWord(tester);
    expect(menuItems(), findsNWidgets(4));
    expect(controller.selection.isCollapsed, isFalse);
    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();
    expect(menuItems(), findsNothing);
    expect(controller.selection.isCollapsed, isTrue);

    await selectWord(tester);
    expect(controller.selection.isCollapsed, isFalse);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(menuItems(), findsNothing);
    expect(controller.selection.isCollapsed, isTrue);
    expect(find.byType(SourceEditorContent), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('scrolling passes through the open menu and clears selection', (
    tester,
  ) async {
    final controller = CodeLineEditingController.fromText(
      List.generate(100, (i) => 'const example$i = $i;').join('\n'),
    );
    addTearDown(controller.dispose);
    await pumpEditor(tester, controller);
    await selectWord(tester);
    expect(menuItems(), findsNWidgets(4));
    final scrollable = tester
        .stateList<ScrollableState>(
          find.descendant(
            of: find.byType(CodeEditor),
            matching: find.byType(Scrollable),
          ),
        )
        .firstWhere((state) => state.position.axis == Axis.vertical);
    final before = scrollable.position.pixels;
    final rect = tester.getRect(find.byType(CodeEditor));
    await tester.dragFrom(
      rect.centerRight - const Offset(30, 0),
      const Offset(0, -200),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(before));
    expect(menuItems(), findsNothing);
    expect(controller.selection.isCollapsed, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('select all keeps selection available for paste', (tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {'text': 'replacement source'}
          : null,
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });
    final controller = CodeLineEditingController.fromText('const example = 1;');
    addTearDown(controller.dispose);
    await pumpEditor(tester, controller);
    await selectWord(tester);
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(controller.selectedText, controller.text);
    expect(menuItems(), findsNWidgets(4));
    await tester.tap(find.text('Paste'));
    await tester.pumpAndSettle();
    expect(controller.text, 'replacement source');
    expect(controller.selection.isCollapsed, isTrue);
    expect(menuItems(), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}

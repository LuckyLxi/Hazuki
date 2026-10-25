import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/widgets/hazuki_morph_dialog.dart';

void main() {
  const startRect = Rect.fromLTWH(40, 60, 200, 36);
  const endRect = Rect.fromLTWH(20, 150, 300, 300);
  const shellKey = ValueKey<String>('shell');
  const contentKey = ValueKey<String>('content');
  const launcherColor = Color(0xFF2196F3);

  Widget buildShell(Animation<double> animation, {Alignment? alignment}) {
    return HazukiMorphDialogShell(
      animation: animation,
      startRect: startRect,
      endRect: endRect,
      launcherColor: launcherColor,
      launcherBorderColor: Colors.red,
      launcherOverlay: const Text('launcher'),
      beginRadius: 12,
      radiusGrowth: 16,
      beginElevation: 4,
      elevationGrowth: 4,
      contentAlignment: alignment,
      shellKey: shellKey,
      child: const SizedBox.expand(key: contentKey),
    );
  }

  Future<void> pumpDialogLauncher(
    WidgetTester tester, {
    required Future<void> Function(BuildContext context) onPressed,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => onPressed(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('returns only after the dialog route is disposed', (
    tester,
  ) async {
    var completed = false;
    var landingCount = 0;
    await pumpDialogLauncher(
      tester,
      onPressed: (context) async {
        await showHazukiMorphDialog<void>(
          context: context,
          onLanding: () => landingCount++,
          builder: (dialogContext, animation) => buildShell(animation),
        );
        completed = true;
      },
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byKey(shellKey), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(completed, isFalse);

    await tester.pumpAndSettle();
    expect(find.byKey(shellKey), findsNothing);
    expect(completed, isTrue);
    expect(landingCount, 1);
  });

  testWidgets('morphs from the start rect to the end rect', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 420),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: buildShell(controller, alignment: Alignment.center)),
    );

    expect(tester.getRect(find.byKey(shellKey)), startRect);
    final startMaterial = tester.widget<Material>(find.byKey(shellKey));
    expect(startMaterial.color, launcherColor);
    expect(startMaterial.elevation, 4);
    // 起点阶段内容已按终点尺寸布局，只是被外壳裁剪。
    expect(tester.getSize(find.byKey(contentKey)), endRect.size);

    controller.value = 1;
    await tester.pump();

    expect(tester.getRect(find.byKey(shellKey)), endRect);
    final endMaterial = tester.widget<Material>(find.byKey(shellKey));
    expect(endMaterial.elevation, 8);
    final shape = endMaterial.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(28));
    expect(shape.side.color, Colors.transparent);
  });

  testWidgets('fill layout sizes content with the shell', (tester) async {
    final controller = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 420),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(home: buildShell(controller)));

    expect(tester.getSize(find.byKey(contentKey)), startRect.size);
  });

  testWidgets('capsule hides while closed and bounces on landing', (
    tester,
  ) async {
    var visible = true;
    var landingVersion = 0;
    late StateSetter update;
    const opacityKey = ValueKey<String>('opacity');
    const landingKey = ValueKey<String>('landing');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              update = setState;
              return HazukiMorphCapsule(
                visible: visible,
                landingVersion: landingVersion,
                onPressed: () {},
                icon: Icons.folder_outlined,
                label: 'Label',
                opacityKey: opacityKey,
                landingKey: landingKey,
              );
            },
          ),
        ),
      ),
    );

    update(() => visible = false);
    await tester.pump();
    expect(tester.widget<Opacity>(find.byKey(opacityKey)).opacity, 0);

    update(() {
      visible = true;
      landingVersion++;
    });
    await tester.pump();
    expect(tester.widget<Opacity>(find.byKey(opacityKey)).opacity, 1);
    expect(
      tester
          .widget<Transform>(find.byKey(landingKey))
          .transform
          .getTranslation()
          .y,
      closeTo(-3, 0.1),
    );

    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(find.byKey(landingKey))
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
  });
}

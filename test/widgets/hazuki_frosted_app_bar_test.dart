import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

import 'package:hazuki/shared/window/window_title_bar_control.dart';
import 'package:hazuki/shared/window/windows_app_bar_drag_area.dart';
import 'package:hazuki/widgets/hazuki_frosted_app_bar.dart';

class _TestWindowTitleBarControl extends ChangeNotifier
    implements WindowTitleBarControl {
  @override
  bool get shouldShowCustomTitleBar => true;

  @override
  bool get useSystemTitleBar => false;

  @override
  void releaseCustomTitleBarSuppression(Object owner) {}

  @override
  void suppressCustomTitleBar(Object owner) {}

  @override
  Future<void> updateUseSystemTitleBar(bool value) async {}
}

void main() {
  testWidgets('top half of app bar controls receives taps immediately', (
    tester,
  ) async {
    final titleBarControl = _TestWindowTitleBarControl();
    var leadingTapCount = 0;
    var titleTapCount = 0;
    var actionTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(platform: TargetPlatform.windows),
        home: HazukiWindowsTitleBarScope(
          controller: titleBarControl,
          child: Builder(
            builder: (context) {
              return Scaffold(
                appBar: hazukiFrostedAppBar(
                  context: context,
                  leading: IconButton(
                    key: const ValueKey('leading-button'),
                    onPressed: () => leadingTapCount++,
                    icon: const Icon(Icons.arrow_back),
                  ),
                  title: InkWell(
                    key: const ValueKey('title-button'),
                    onTap: () => titleTapCount++,
                    child: const SizedBox(width: 240, height: 40),
                  ),
                  actions: [
                    IconButton(
                      key: const ValueKey('action-button'),
                      onPressed: () => actionTapCount++,
                      icon: const Icon(Icons.more_vert),
                    ),
                  ],
                ),
                body: const SizedBox.expand(),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byType(DragToMoveArea), findsOneWidget);

    final leadingRect = tester.getRect(
      find.byKey(const ValueKey('leading-button')),
    );
    await tester.tapAt(Offset(leadingRect.center.dx, leadingRect.top + 8));
    expect(leadingTapCount, 1);

    final titleRect = tester.getRect(
      find.byKey(const ValueKey('title-button')),
    );
    await tester.tapAt(Offset(titleRect.center.dx, titleRect.top + 4));
    expect(titleTapCount, 1);

    final actionRect = tester.getRect(
      find.byKey(const ValueKey('action-button')),
    );
    expect(
      actionRect.right,
      lessThanOrEqualTo(800 - hazukiWindowsCaptionButtonsWidth),
    );
    await tester.tapAt(Offset(actionRect.center.dx, actionRect.top + 8));
    expect(actionTapCount, 1);
  });
}

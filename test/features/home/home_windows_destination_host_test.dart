import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/features/home/view/home_windows_destination_host.dart';

void main() {
  Future<void> pumpHost(
    WidgetTester tester, {
    required HomeDrawerDestination? destination,
    VoidCallback? onCloseRequested,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: HomeWindowsDestinationHost(
          destination: destination,
          onCloseRequested: onCloseRequested ?? () {},
          destinationBuilder: (context, destination) => Scaffold(
            body: Column(
              children: [
                Text('page-${destination.name}'),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(body: Text('sub-page')),
                    ),
                  ),
                  child: const Text('open-sub'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('close'),
                ),
              ],
            ),
          ),
          homeChild: const Scaffold(body: Text('home')),
        ),
      ),
    );
  }

  testWidgets('keeps home mounted and shows the destination above it', (
    tester,
  ) async {
    await pumpHost(tester, destination: null);
    expect(find.text('home'), findsOneWidget);

    await pumpHost(tester, destination: HomeDrawerDestination.history);
    await tester.pumpAndSettle();

    expect(find.text('page-history'), findsOneWidget);
    expect(find.text('home', skipOffstage: false), findsOneWidget);
  });

  testWidgets('sub pages stay inside the destination navigator', (
    tester,
  ) async {
    await pumpHost(tester, destination: HomeDrawerDestination.settings);
    await tester.pumpAndSettle();

    await tester.tap(find.text('open-sub'));
    await tester.pumpAndSettle();
    expect(find.text('sub-page'), findsOneWidget);

    // 切换到其他侧栏页面时，原导航栈整体替换。
    await pumpHost(tester, destination: HomeDrawerDestination.downloads);
    await tester.pumpAndSettle();
    expect(find.text('sub-page'), findsNothing);
    expect(find.text('page-downloads'), findsOneWidget);
  });

  testWidgets('popping the root page requests closing the destination', (
    tester,
  ) async {
    var closeRequests = 0;
    await pumpHost(
      tester,
      destination: HomeDrawerDestination.history,
      onCloseRequested: () => closeRequests += 1,
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('close'));
    await tester.pumpAndSettle();

    expect(closeRequests, 1);
  });
}

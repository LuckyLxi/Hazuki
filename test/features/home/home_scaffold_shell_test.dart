import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/features/home/view/home_scaffold_shell.dart';

void main() {
  test('home pop request exits after confirmation', () async {
    var exitRequested = false;

    await handleHomePopRequest(
      onWillPop: () async => true,
      onExitRequested: () async {
        exitRequested = true;
      },
    );

    expect(exitRequested, isTrue);
  });

  test('home pop request stays on home before confirmation', () async {
    var exitRequested = false;

    await handleHomePopRequest(
      onWillPop: () async => false,
      onExitRequested: () async {
        exitRequested = true;
      },
    );

    expect(exitRequested, isFalse);
  });
}

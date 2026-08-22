import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/shared/favorites/favorite_page_actions.dart';

void main() {
  test('binding relays back-to-top visibility and action', () async {
    final binding = FavoritePageActionsBinding();
    final actions = _FakeFavoritePageActions();
    var notifications = 0;
    binding.addListener(() => notifications++);

    binding.attach(actions);
    binding.updateBackToTopVisibility(actions, visible: true);

    expect(binding.backToTopVisible, isTrue);
    expect(notifications, 1);

    await binding.scrollToTop();
    expect(actions.scrollToTopCalls, 1);

    binding.detach(actions);
    expect(binding.backToTopVisible, isFalse);
    expect(notifications, 2);

    binding.dispose();
  });
}

class _FakeFavoritePageActions implements FavoritePageActions {
  @override
  bool get backToTopVisible => false;

  int scrollToTopCalls = 0;

  @override
  Future<void> changeSortOrder(String order) async {}

  @override
  Future<void> createFolder() async {}

  @override
  Future<void> scrollToTop() async {
    scrollToTopCalls++;
  }

  @override
  Future<void> toggleMode() async {}
}

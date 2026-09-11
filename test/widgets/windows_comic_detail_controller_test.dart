import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

void main() {
  const first = ExploreComic(id: 'first', title: '', subTitle: '', cover: '');
  const second = ExploreComic(id: 'second', title: '', subTitle: '', cover: '');

  test(
    'independent detail sessions restore history and reset on replacement',
    () {
      final controller = WindowsComicDetailController();
      final other = WindowsComicDetailController();
      addTearDown(controller.dispose);
      addTearDown(other.dispose);

      controller.open(first, 'first');
      expect(controller.entry!.navigation, WindowsComicDetailNavigation.open);
      controller.pushRelated(second, 'second', historyTabIndex: 2);
      expect(controller.entry!.navigation, WindowsComicDetailNavigation.push);
      controller.goBack();
      expect(controller.entry!.comic, first);
      expect(controller.entry!.initialTabIndex, 2);
      expect(controller.entry!.navigation, WindowsComicDetailNavigation.pop);

      controller.open(second, 'second');
      expect(
        controller.entry!.navigation,
        WindowsComicDetailNavigation.replace,
      );
      expect(controller.canGoBack, isFalse);
      controller.goBack();
      expect(controller.isOpen, isFalse);
      expect(other.isOpen, isFalse);
    },
  );

  test('stale hide completion cannot reveal a newly hidden detail', () {
    final controller = WindowsComicDetailController();
    addTearDown(controller.dispose);
    controller.open(first, 'first');
    final staleToken = controller.beginTemporaryHide();
    controller.open(second, 'second');
    final currentToken = controller.beginTemporaryHide();

    controller.endTemporaryHide(staleToken);
    expect(controller.isPanelVisible, isFalse);
    controller.endTemporaryHide(currentToken);
    expect(controller.isPanelVisible, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

void main() {
  const first = ExploreComic(id: 'first', title: '', subTitle: '', cover: '');
  const second = ExploreComic(id: 'second', title: '', subTitle: '', cover: '');
  const third = ExploreComic(id: 'third', title: '', subTitle: '', cover: '');

  test('suspended snapshot restores the full back stack and tab state', () {
    final controller = WindowsComicDetailController();
    addTearDown(controller.dispose);
    controller.open(first, 'first');
    controller.pushRelated(second, 'second', historyTabIndex: 2);
    controller.pushRelated(third, 'third', historyTabIndex: 1);
    final snapshot = controller.captureSnapshot()!;
    final epoch = controller.restorationEpoch;

    controller.open(first, 'search-result');
    controller.close();
    controller.restoreSuspended(snapshot, restorationEpoch: epoch);

    expect(controller.entry!.comic, third);
    expect(controller.entry!.navigation, WindowsComicDetailNavigation.resume);
    expect(controller.entry!.revision, greaterThan(snapshot.entry.revision));
    expect(controller.canGoBack, isTrue);
    controller.goBack();
    expect(controller.entry!.comic, second);
    expect(controller.entry!.heroTag, 'second');
    expect(controller.entry!.initialTabIndex, 1);
    expect(controller.canGoBack, isTrue);
    controller.goBack();
    expect(controller.entry!.comic, first);
    expect(controller.entry!.heroTag, 'first');
    expect(controller.entry!.initialTabIndex, 2);
    expect(controller.canGoBack, isFalse);
    controller.goBack();
    expect(controller.isOpen, isFalse);
  });

  test('suspended history cannot replace an active or discarded session', () {
    final controller = WindowsComicDetailController();
    addTearDown(controller.dispose);
    controller.open(first, 'first');
    controller.pushRelated(second, 'second', historyTabIndex: 2);
    final snapshot = controller.captureSnapshot()!;
    final epoch = controller.restorationEpoch;

    controller.open(third, 'third');
    controller.restoreSuspended(snapshot, restorationEpoch: epoch);
    expect(controller.entry!.comic, third);
    expect(controller.canGoBack, isFalse);

    controller.close(discardSuspendedDetails: true);
    controller.restoreSuspended(snapshot, restorationEpoch: epoch);
    expect(controller.isOpen, isFalse);
    expect(controller.canGoBack, isFalse);
  });

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

import 'package:flutter/material.dart';

import 'package:hazuki/features/home/support/home_sidebar_models.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

typedef HomeWindowsDestinationBuilder =
    Widget Function(BuildContext context, HomeDrawerDestination destination);

/// Windows 右侧内容区：首页内容常驻在下层，侧栏页面在上层的独立导航栈中打开。
///
/// 侧栏页面及其子页面都留在内容区内，侧栏保持可点；阅读器等全屏页面
/// 通过根导航打开，仍然盖满整个窗口。
class HomeWindowsDestinationHost extends StatefulWidget {
  const HomeWindowsDestinationHost({
    super.key,
    required this.destination,
    required this.destinationBuilder,
    required this.onCloseRequested,
    required this.homeChild,
  });

  final HomeDrawerDestination? destination;
  final HomeWindowsDestinationBuilder destinationBuilder;

  /// 侧栏页面的根页面被关闭（如页面自身调用 pop）时回调，由外层回到首页。
  final VoidCallback onCloseRequested;
  final Widget homeChild;

  @override
  State<HomeWindowsDestinationHost> createState() =>
      _HomeWindowsDestinationHostState();
}

class _HomeWindowsDestinationHostState
    extends State<HomeWindowsDestinationHost> {
  static const _fadeDuration = Duration(milliseconds: 220);
  static const _slideDuration = Duration(milliseconds: 240);

  WindowsComicDetailController? _detailController;
  int _detailHideToken = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detailController = WindowsComicDetailControllerScope.of(context);
    _syncDetailPanelHide();
  }

  @override
  void didUpdateWidget(HomeWindowsDestinationHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.destination == null) != (widget.destination == null)) {
      _syncDetailPanelHide();
    }
  }

  // 打开侧栏页面时暂时隐藏首页的详情面板，回到首页后恢复。
  void _syncDetailPanelHide() {
    final controller = _detailController;
    if (controller == null) return;
    if (widget.destination != null && _detailHideToken == 0) {
      _detailHideToken = controller.beginTemporaryHide();
    } else if (widget.destination == null && _detailHideToken != 0) {
      controller.endTemporaryHide(_detailHideToken);
      _detailHideToken = 0;
    }
  }

  @override
  void dispose() {
    if (_detailHideToken != 0) {
      _detailController?.endTemporaryHide(_detailHideToken);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final homeActive = destination == null;
    return Stack(
      fit: StackFit.expand,
      children: [
        // 首页保持挂载以保留滚动位置和已加载内容，被遮住时不参与命中、焦点与 Hero。
        HeroMode(
          enabled: homeActive,
          child: ExcludeFocus(
            excluding: !homeActive,
            child: IgnorePointer(
              ignoring: !homeActive,
              child: AnimatedOpacity(
                duration: _fadeDuration,
                curve: Curves.easeOut,
                opacity: homeActive ? 1 : 0,
                child: widget.homeChild,
              ),
            ),
          ),
        ),
        AnimatedSwitcher(
          duration: _slideDuration,
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          layoutBuilder: (current, previous) =>
              Stack(fit: StackFit.expand, children: [...previous, ?current]),
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.03, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          ),
          child: destination == null
              ? const SizedBox.shrink(key: ValueKey('windows-destination-none'))
              : _HomeWindowsDestinationNavigator(
                  key: ValueKey('windows-destination-${destination.name}'),
                  destination: destination,
                  builder: widget.destinationBuilder,
                  onRootRemoved: widget.onCloseRequested,
                ),
        ),
      ],
    );
  }
}

class _HomeWindowsDestinationNavigator extends StatefulWidget {
  const _HomeWindowsDestinationNavigator({
    super.key,
    required this.destination,
    required this.builder,
    required this.onRootRemoved,
  });

  final HomeDrawerDestination destination;
  final HomeWindowsDestinationBuilder builder;
  final VoidCallback onRootRemoved;

  @override
  State<_HomeWindowsDestinationNavigator> createState() =>
      _HomeWindowsDestinationNavigatorState();
}

class _HomeWindowsDestinationNavigatorState
    extends State<_HomeWindowsDestinationNavigator> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  int _rootGeneration = 0;
  late Page<void> _rootPage = _buildRootPage();

  Page<void> _buildRootPage() => MaterialPage<void>(
    key: ValueKey(
      'windows-destination-page-${widget.destination.name}-$_rootGeneration',
    ),
    child: Builder(
      builder: (context) => widget.builder(context, widget.destination),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (_) => _navigatorKey.currentState?.maybePop(),
      child: Navigator(
        key: _navigatorKey,
        pages: [_rootPage],
        // 根页面被页面自身 pop 掉时交给外层回到首页；同时补一个新根页面，
        // 保证退场动画期间导航栈不为空。
        onDidRemovePage: (page) {
          if (!identical(page, _rootPage)) return;
          setState(() {
            _rootGeneration += 1;
            _rootPage = _buildRootPage();
          });
          widget.onRootRemoved();
        },
      ),
    );
  }
}

part of 'comments_page.dart';

class _CommentsTabClampingScrollPhysics extends ClampingScrollPhysics {
  const _CommentsTabClampingScrollPhysics({super.parent});

  @override
  _CommentsTabClampingScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _CommentsTabClampingScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  bool get allowImplicitScrolling => false;
}

class _SuppressShowOnScreen extends SingleChildRenderObjectWidget {
  const _SuppressShowOnScreen({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSuppressShowOnScreen();
  }
}

class _RenderSuppressShowOnScreen extends RenderProxyBox {
  @override
  void showOnScreen({
    RenderObject? descendant,
    Rect? rect,
    Duration duration = Duration.zero,
    Curve curve = Curves.ease,
  }) {
    // The composer is already pinned on screen, so suppress framework-driven
    // focus reveal scrolling and let the detail-page fullscreen logic decide
    // whether any outer scroll is needed.
  }
}

import 'package:flutter/widgets.dart';

/// 跟踪所在路由的入场过渡是否已经结束。
///
/// 页面可据此把大量控件的构建推迟到滑入动画之后，避免挤进动画帧造成掉帧。
/// 一旦结束就保持为 true，返回手势或退出动画不会再把它置回。
mixin RouteTransitionSettledMixin<T extends StatefulWidget> on State<T> {
  ModalRoute<Object?>? _transitionRoute;
  Animation<double>? _transitionAnimation;
  bool _routeTransitionSettled = false;

  bool get routeTransitionSettled => _routeTransitionSettled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeTransitionSettled) return;
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (route == null || animation == null) {
      _routeTransitionSettled = true;
      return;
    }
    _transitionRoute = route;
    if (!identical(animation, _transitionAnimation)) {
      _transitionAnimation?.removeStatusListener(_onTransitionStatusChanged);
      _transitionAnimation = animation;
      animation.addStatusListener(_onTransitionStatusChanged);
    }
    // Hero 预构建时路由处于 offstage，动画代理会暂时指向已完成状态，需等真正入场后再判断
    if (!route.offstage && animation.isCompleted) _settleRouteTransition();
  }

  void _onTransitionStatusChanged(AnimationStatus status) {
    if (!status.isCompleted || _transitionRoute?.offstage != false) return;
    if (!mounted || _routeTransitionSettled) return;
    setState(_settleRouteTransition);
  }

  void _settleRouteTransition() {
    _routeTransitionSettled = true;
    _transitionAnimation?.removeStatusListener(_onTransitionStatusChanged);
    didSettleRouteTransition();
  }

  /// 入场过渡结束时调用一次，可能发生在 setState 回调或首次构建之前，
  /// 子类只应在这里修改状态，不要再调用 setState
  @protected
  void didSettleRouteTransition() {}

  @override
  void dispose() {
    _transitionAnimation?.removeStatusListener(_onTransitionStatusChanged);
    super.dispose();
  }
}

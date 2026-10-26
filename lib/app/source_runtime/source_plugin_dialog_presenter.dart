import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/models/hazuki_models.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/shared/navigation_tags.dart';
import 'package:hazuki/shared/source_account/source_account_dialog_support.dart';
import 'package:hazuki/shared/source_interaction/source_animated_dialog.dart';
import 'package:hazuki/shared/source_account/source_browser_authorization_dialog.dart';
import 'package:hazuki/shared/source_account/source_authorization_browser.dart';
import 'package:hazuki/shared/source_interaction/source_plugin_dialog.dart';
import 'package:hazuki/shared/windows/windows_comic_detail.dart';

/// Observes exact route identities, excluding this presenter's own dialog route.
class SourcePluginDialogPresenter extends NavigatorObserver {
  SourcePluginDialogPresenter(
    this.navigatorKey, {
    this.browserFactory,
    this.comicDetailPageBuilder,
    this.searchPageBuilder,
  }) {
    final service = SourceUiService.instance;
    service.presenter = present;
    service.captureOwner = () =>
        _routes.where((r) => !_dialogRoutes.contains(r)).lastOrNull;
    service.isOwnerAvailable = (_) => navigatorKey.currentState != null;
    service.canPresent = (_) => navigatorKey.currentState != null;
  }
  final GlobalKey<NavigatorState> navigatorKey;
  final SourceAuthorizationBrowser Function()? browserFactory;

  /// 弹窗内漫画卡片与搜索型标签的跳转目标；为空时对应组件不可点击。
  final Widget Function(ExploreComic comic, String heroTag)?
  comicDetailPageBuilder;
  final Widget Function(String keyword)? searchPageBuilder;
  final List<Route<dynamic>> _routes = [];
  final Set<Route<dynamic>> _dialogRoutes = {};
  final Map<Route<dynamic>, SourceDialogSession> _sessions = {};
  bool _pushingDialog = false;
  SourceDialogSession? _pushingSession;

  Future<void> present(SourceDialogSession dialog) async {
    final context = navigatorKey.currentState?.overlay?.context;
    if (context == null || dialog.isClosed) {
      dialog.close('ownerGone');
      return;
    }
    Route<dynamic>? route;
    void changed() {
      final current = route;
      if (dialog.isClosed && current != null && current.isActive) {
        scheduleMicrotask(() {
          if (!current.isActive) return;
          if (current.isCurrent) {
            current.navigator?.pop();
          } else {
            current.navigator?.removeRoute(current);
          }
        });
      }
    }

    dialog.addListener(changed);
    _pushingDialog = true;
    _pushingSession = dialog;
    try {
      final sheet = dialog.model.presentation == 'sheet';
      Widget content(BuildContext context) {
        route = ModalRoute.of(context);
        return SourcePluginDialog(
          dialog: dialog,
          sheet: sheet,
          onOpenComic: comicDetailPageBuilder == null
              ? null
              : (comic) => _openComic(dialog, comic),
          onSearch: searchPageBuilder == null
              ? null
              : (keyword) => _search(dialog, keyword),
        );
      }

      final shown = dialog.browserRequest != null
          ? _presentBrowser(context, dialog)
          : sheet
          ? showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              showDragHandle: true,
              backgroundColor: homeDialogBackgroundColor(context),
              constraints: const BoxConstraints(maxWidth: 640),
              builder: content,
            )
          : showSourceAnimatedDialog<void>(
              context,
              child: Builder(builder: content),
            );
      route ??= _routes.lastOrNull;
      changed();
      _pushingDialog = false;
      _pushingSession = null;
      await shown;
      final transition = route;
      if (transition is TransitionRoute<dynamic>) {
        await transition.completed;
      }
    } finally {
      _pushingDialog = false;
      _pushingSession = null;
      dialog.removeListener(changed);
      // Browser failures must reach the queue before the session is closed.
      if (dialog.browserRequest == null) dialog.close('user');
    }
  }

  Future<void> _presentBrowser(
    BuildContext context,
    SourceDialogSession dialog,
  ) async {
    dialog.markShown();
    final result = await showSourceBrowserAuthorization(
      context,
      {...dialog.browserRequest!, 'sourceName': dialog.sourceName},
      dialog.browserCancellation,
      browserFactory: browserFactory,
    );
    dialog.completeBrowser(result);
  }

  /// 关闭窗口（reason 为 navigated，不取消插件操作）后打开目标页面。
  void _openComic(SourceDialogSession dialog, ExploreComic comic) {
    final context = navigatorKey.currentState?.overlay?.context;
    final builder = comicDetailPageBuilder;
    if (context == null || builder == null || dialog.isClosed) return;
    dialog.close('navigated');
    unawaited(
      openComicDetail(
        context,
        comic: comic,
        heroTag: comicCoverHeroTag(comic, salt: 'plugin-dialog-${dialog.id}'),
        pageBuilder: builder,
      ),
    );
  }

  void _search(SourceDialogSession dialog, String keyword) {
    final navigator = navigatorKey.currentState;
    final builder = searchPageBuilder;
    if (navigator == null || builder == null || dialog.isClosed) return;
    dialog.close('navigated');
    unawaited(
      navigator.push<void>(
        MaterialPageRoute<void>(builder: (_) => builder(keyword)),
      ),
    );
  }

  void _sync() {
    final service = SourceUiService.instance;
    service.schedulePump();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _routes.add(route);
    if (_pushingDialog) {
      _dialogRoutes.add(route);
      if (_pushingSession != null) _sessions[route] = _pushingSession!;
    }
    _sync();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final dialog = _sessions.remove(route);
    // Browser completion is resolved after its route returns. Do not turn a
    // successful navigation into cancellation while that result is in flight.
    if (dialog?.browserRequest == null) dialog?.close('user');
    _routes.remove(route);
    _dialogRoutes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    final dialog = _sessions.remove(route);
    if (dialog?.browserRequest == null) dialog?.close('user');
    _routes.remove(route);
    _dialogRoutes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    final dialog = _sessions.remove(oldRoute);
    if (dialog?.browserRequest == null) dialog?.close('user');
    _routes.remove(oldRoute);
    _dialogRoutes.remove(oldRoute);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
    }
    _sync();
  }

  void dispose() => SourceUiService.instance.detach();
}

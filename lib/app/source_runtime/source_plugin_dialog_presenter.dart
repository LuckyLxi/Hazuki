import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/shared/source_account/source_account_dialog_support.dart';
import 'package:hazuki/shared/source_account/source_browser_authorization_dialog.dart';
import 'package:hazuki/shared/source_account/source_authorization_browser.dart';
import 'package:hazuki/shared/source_interaction/source_plugin_dialog.dart';

/// Observes exact route identities, excluding this presenter's own dialog route.
class SourcePluginDialogPresenter extends NavigatorObserver {
  SourcePluginDialogPresenter(this.navigatorKey, {this.browserFactory}) {
    final service = SourceUiService.instance;
    service.presenter = present;
    service.captureOwner = () =>
        _routes.where((r) => !_dialogRoutes.contains(r)).lastOrNull;
    service.isOwnerAvailable = (_) => navigatorKey.currentState != null;
    service.canPresent = (_) => navigatorKey.currentState != null;
  }
  final GlobalKey<NavigatorState> navigatorKey;
  final SourceAuthorizationBrowser Function()? browserFactory;
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
      final shown = dialog.browserRequest != null
          ? _presentBrowser(context, dialog)
          : showHomeAnimatedDialog<void>(
              context,
              child: Builder(
                builder: (context) {
                  route = ModalRoute.of(context);
                  return SourcePluginDialog(dialog: dialog);
                },
              ),
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

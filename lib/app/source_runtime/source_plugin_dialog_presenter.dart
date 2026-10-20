import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hazuki/services/source/interaction/source_ui_service.dart';
import 'package:hazuki/shared/source_account/source_account_dialog_support.dart';
import 'package:hazuki/shared/source_interaction/source_plugin_dialog.dart';

/// Observes exact route identities, excluding this presenter's own dialog route.
class SourcePluginDialogPresenter extends NavigatorObserver {
  SourcePluginDialogPresenter(this.navigatorKey) {
    final service = SourceUiService.instance;
    service.presenter = present;
    service.captureOwner = () =>
        _routes.where((r) => !_dialogRoutes.contains(r)).lastOrNull;
    service.isOwnerAvailable = (owner) {
      final index = owner is Route<dynamic> ? _routes.indexOf(owner) : -1;
      return index >= 0 &&
          !_routes.skip(index + 1).any((route) => route is PageRoute);
    };
    service.canPresent = (owner) =>
        owner != null && _routes.isNotEmpty && identical(owner, _routes.last);
  }
  final GlobalKey<NavigatorState> navigatorKey;
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
      final shown = showHomeAnimatedDialog<void>(
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
      dialog.close('user');
    }
  }

  void _sync() {
    final service = SourceUiService.instance;
    for (final scope in service.scopes) {
      if (scope.owner is Route && !_routes.contains(scope.owner)) {
        scope.cancel('ownerGone');
      } else if (_routes.isNotEmpty &&
          scope.owner != null &&
          !identical(scope.owner, _routes.last) &&
          !_dialogRoutes.contains(_routes.last)) {
        scope.cancel('ownerGone');
      }
    }
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
    _sessions.remove(route)?.close('user');
    _routes.remove(route);
    _dialogRoutes.remove(route);
    _sync();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _sessions.remove(route)?.close('user');
    _routes.remove(route);
    _dialogRoutes.remove(route);
    _sync();
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final index = oldRoute == null ? -1 : _routes.indexOf(oldRoute);
    _routes.remove(oldRoute);
    _dialogRoutes.remove(oldRoute);
    if (newRoute != null) {
      _routes.insert(index < 0 ? _routes.length : index, newRoute);
    }
    _sync();
  }

  void dispose() => SourceUiService.instance.detach();
}

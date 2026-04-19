import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SearchFocusCoordinator extends ChangeNotifier {
  SearchFocusCoordinator({
    required bool Function() isMounted,
    String initialText = '',
    bool allowCollapsedFocus = true,
  }) : _isMounted = isMounted,
       primaryController = TextEditingController(text: initialText),
       collapsedController = TextEditingController(text: initialText),
       primaryFocusNode = FocusNode(debugLabel: 'search_primary_focus'),
       collapsedFocusNode = FocusNode(
         debugLabel: 'search_collapsed_focus',
         canRequestFocus: allowCollapsedFocus,
         skipTraversal: !allowCollapsedFocus,
       ),
       pageFocusNode = FocusNode(
         debugLabel: 'search_page_focus',
         skipTraversal: true,
       ) {
    primaryController.addListener(_onTextChanged);
    collapsedController.addListener(_onTextChanged);
    primaryFocusNode.addListener(_onFocusChanged);
    collapsedFocusNode.addListener(_onFocusChanged);
  }

  final bool Function() _isMounted;
  final TextEditingController primaryController;
  final TextEditingController collapsedController;
  final FocusNode primaryFocusNode;
  final FocusNode collapsedFocusNode;
  final FocusNode pageFocusNode;

  bool _keyboardVisible = false;
  bool _collapsedSearchExpanded = false;
  bool _awaitingCollapsedSearchFocus = false;
  bool _routeAutoFocusAttached = false;
  bool _routeAutoFocusCancelled = false;
  Animation<double>? _routeAnimation;
  BuildContext? _routeAutoFocusContext;
  bool _disposed = false;

  bool get keyboardVisible => _keyboardVisible;
  bool get collapsedSearchExpanded => _collapsedSearchExpanded;
  bool get awaitingCollapsedSearchFocus => _awaitingCollapsedSearchFocus;
  bool get collapsedHasFocus => collapsedFocusNode.hasFocus;
  bool get primaryHasFocus => primaryFocusNode.hasFocus;
  String get text => primaryController.text;
  TextEditingController get activeController =>
      collapsedFocusNode.hasFocus ? collapsedController : primaryController;

  void _onTextChanged() {
    _notify();
  }

  void _onFocusChanged() {
    final collapsedHasFocus = collapsedFocusNode.hasFocus;
    if (collapsedHasFocus && _awaitingCollapsedSearchFocus) {
      _awaitingCollapsedSearchFocus = false;
    }

    if (!collapsedHasFocus &&
        _collapsedSearchExpanded &&
        !_keyboardVisible &&
        !_awaitingCollapsedSearchFocus) {
      _collapsedSearchExpanded = false;
    }

    _notify();
  }

  void syncKeyboardVisibility() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final view = views.isNotEmpty ? views.first : null;
    final nextKeyboardVisible = (view?.viewInsets.bottom ?? 0) > 0;
    final keyboardJustClosed = _keyboardVisible && !nextKeyboardVisible;
    _keyboardVisible = nextKeyboardVisible;

    if (_keyboardVisible && _awaitingCollapsedSearchFocus) {
      _awaitingCollapsedSearchFocus = false;
    }

    if (keyboardJustClosed &&
        _collapsedSearchExpanded &&
        collapsedFocusNode.hasFocus) {
      _awaitingCollapsedSearchFocus = false;
      collapsedFocusNode.unfocus();
      _collapsedSearchExpanded = false;
    }

    _notify();
  }

  void syncText(
    String value, {
    bool updatePrimary = true,
    bool updateCollapsed = true,
  }) {
    if (updatePrimary && primaryController.text != value) {
      primaryController.value = primaryController.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
    if (updateCollapsed && collapsedController.text != value) {
      collapsedController.value = collapsedController.value.copyWith(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
        composing: TextRange.empty,
      );
    }
  }

  void clearText() {
    primaryController.clear();
    collapsedController.clear();
  }

  void attachRouteAutoFocus(
    BuildContext context, {
    required bool showKeyboard,
  }) {
    if (_routeAutoFocusAttached || !showKeyboard || !_isMounted()) {
      return;
    }
    _routeAutoFocusAttached = true;
    _routeAutoFocusContext = context;
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null || animation.isCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_canRunScheduledAction()) {
          return;
        }
        unawaited(
          requestPrimarySearchFocus(context, showKeyboard: showKeyboard),
        );
      });
      return;
    }
    _routeAnimation = animation;
    animation.addStatusListener(_handleRouteAnimationStatus);
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) {
      return;
    }
    final animation = _routeAnimation;
    animation?.removeStatusListener(_handleRouteAnimationStatus);
    _routeAnimation = null;
    final context = _routeAutoFocusContext;
    if (context != null && _canRunScheduledAction()) {
      unawaited(requestPrimarySearchFocus(context));
    }
  }

  bool _canRunScheduledAction() {
    return !_disposed && _isMounted() && !_routeAutoFocusCancelled;
  }

  Future<void> requestPrimarySearchFocus(
    BuildContext context, {
    bool showKeyboard = true,
  }) async {
    cancelPendingAutoFocus();
    if (!_isMounted()) {
      return;
    }
    primaryFocusNode.requestFocus();
    if (!showKeyboard) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (!_isMounted() || !primaryFocusNode.hasFocus) {
      return;
    }
    await SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void cancelPendingAutoFocus() {
    _routeAutoFocusCancelled = true;
    final animation = _routeAnimation;
    if (animation != null) {
      animation.removeStatusListener(_handleRouteAnimationStatus);
      _routeAnimation = null;
    }
    _routeAutoFocusContext = null;
  }

  void dismissKeyboard(BuildContext context, {bool parkOnPage = false}) {
    cancelPendingAutoFocus();
    FocusManager.instance.primaryFocus?.unfocus();
    if (parkOnPage) {
      pageFocusNode.requestFocus();
    }
  }

  void enterCollapsedMode(BuildContext context) {
    _collapsedSearchExpanded = true;
    _awaitingCollapsedSearchFocus = true;
    _notify();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isMounted()) {
        return;
      }
      collapsedFocusNode.requestFocus();
    });
  }

  void exitCollapsedMode({bool unfocus = true}) {
    if (unfocus) {
      collapsedFocusNode.unfocus();
    }
    if (!_collapsedSearchExpanded && !_awaitingCollapsedSearchFocus) {
      return;
    }
    _collapsedSearchExpanded = false;
    _awaitingCollapsedSearchFocus = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    cancelPendingAutoFocus();
    primaryController.removeListener(_onTextChanged);
    collapsedController.removeListener(_onTextChanged);
    primaryFocusNode.removeListener(_onFocusChanged);
    collapsedFocusNode.removeListener(_onFocusChanged);
    primaryController.dispose();
    collapsedController.dispose();
    primaryFocusNode.dispose();
    collapsedFocusNode.dispose();
    pageFocusNode.dispose();
    super.dispose();
  }
}

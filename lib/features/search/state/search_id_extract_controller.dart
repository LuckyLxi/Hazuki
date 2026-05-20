import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hazuki/services/hazuki_source_service.dart';
import 'package:hazuki/widgets/widgets.dart';

import '../support/search_shared.dart';

class SearchIdExtractController extends ChangeNotifier {
  SearchIdExtractController({
    required HazukiSourceService sourceService,
    required bool Function() isMounted,
    required bool Function() isInputFocused,
    required String Function() currentText,
  }) : _sourceService = sourceService,
       _isMounted = isMounted,
       _isInputFocused = isInputFocused,
       _currentText = currentText {
    _sourceService.addListener(_handleSourceChanged);
  }

  static const Duration hideDelay = Duration(milliseconds: 300);

  final HazukiSourceService _sourceService;
  final bool Function() _isMounted;
  final bool Function() _isInputFocused;
  final String Function() _currentText;

  bool _enabled = false;
  bool _pendingHide = false;
  bool _disposed = false;
  String? _extractedId;

  String? get extractedId => _extractedId;

  Future<void> load() async {
    final enabled = await isComicIdSearchEnhanceEnabled();
    if (!_canUpdate) {
      return;
    }
    _enabled = enabled && _sourceService.isActiveJmSource;
    _setExtractedId(_extractFromFocusedInput(_currentText()));
  }

  void syncWithFocus(String value) {
    _pendingHide = false;
    _setExtractedId(_extractFromFocusedInput(value));
  }

  void scheduleHideIfUnfocused() {
    if (_pendingHide) {
      return;
    }
    _pendingHide = true;
    Future<void>.delayed(hideDelay, () {
      if (!_canUpdate || !_pendingHide) {
        return;
      }
      _pendingHide = false;
      if (!_isInputFocused()) {
        hide();
      }
    });
  }

  String? captureApplyId() {
    final id = _extractedId;
    if (id == null) {
      return null;
    }
    _pendingHide = false;
    return id;
  }

  void hide() {
    _pendingHide = false;
    _setExtractedId(null);
  }

  bool get _canUpdate => !_disposed && _isMounted();

  String? _extractFromFocusedInput(String value) {
    if (!_enabled || !_isInputFocused()) {
      return null;
    }
    return extractBestComicId(value);
  }

  void _handleSourceChanged() {
    if (!_canUpdate) {
      return;
    }
    if (!_sourceService.isActiveJmSource) {
      _enabled = false;
      _setExtractedId(null);
      return;
    }
    unawaited(load());
  }

  void _setExtractedId(String? id) {
    final changed = id != _extractedId;
    _extractedId = id;
    _syncPromptAnchor(id != null);
    if (changed) {
      notifyListeners();
    }
  }

  void _syncPromptAnchor(bool pillVisible) {
    hazukiPromptPlacementController.setExtraBottomPadding(
      pillVisible ? 36.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _sourceService.removeListener(_handleSourceChanged);
    _syncPromptAnchor(false);
    super.dispose();
  }
}

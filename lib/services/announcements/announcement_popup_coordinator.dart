import 'dart:async';

import 'announcement.dart';
import 'announcement_controller.dart';

typedef AnnouncementPopupPresenter =
    Future<void> Function(Announcement announcement);

class AnnouncementPopupCoordinator {
  AnnouncementPopupCoordinator({
    required AnnouncementController controller,
    required AnnouncementPopupPresenter showAnnouncement,
    required bool Function() isActive,
  }) : _controller = controller,
       _showAnnouncement = showAnnouncement,
       _isActive = isActive;

  final AnnouncementController _controller;
  final AnnouncementPopupPresenter _showAnnouncement;
  final bool Function() _isActive;
  bool _started = false;
  bool _listening = false;
  bool _showing = false;
  bool _disposed = false;

  Future<void> start() async {
    if (_started || _disposed) {
      return;
    }
    _started = true;
    await _controller.refresh();
    if (_disposed) {
      return;
    }
    _controller.addListener(_handleAnnouncementsChanged);
    _listening = true;
    await _showPendingAnnouncements();
  }

  void _handleAnnouncementsChanged() {
    unawaited(_showPendingAnnouncements());
  }

  Future<void> _showPendingAnnouncements() async {
    if (_disposed ||
        !_isActive() ||
        _showing ||
        !_controller.isReadyForPopupPresentation) {
      return;
    }
    _showing = true;
    try {
      while (!_disposed && _isActive()) {
        final announcement = _controller.nextPopupToPresent;
        if (announcement == null) {
          break;
        }
        await _showAnnouncement(announcement);
        await _controller.markPopupPresented(announcement);
      }
    } finally {
      _showing = false;
    }
  }

  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    if (_listening) {
      _controller.removeListener(_handleAnnouncementsChanged);
      _listening = false;
    }
  }
}

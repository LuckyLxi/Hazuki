import 'dart:async';

import 'package:flutter/foundation.dart';

import 'announcement.dart';
import 'announcement_controller.dart';
import 'announcement_manifest_parser.dart';
import 'announcement_remote_source.dart';
import 'announcement_store.dart';

class AnnouncementService extends ChangeNotifier
    implements AnnouncementController {
  AnnouncementService({
    required AnnouncementRemoteSource remoteSource,
    required AnnouncementStore store,
    DateTime Function()? now,
  }) : _remoteSource = remoteSource,
       _store = store,
       _now = now ?? DateTime.now,
       _scheduleTimeTransitions = now == null;

  final AnnouncementRemoteSource _remoteSource;
  final AnnouncementStore _store;
  final DateTime Function() _now;
  final bool _scheduleTimeTransitions;
  List<Announcement> _all = const [];
  Set<String> _readIds = const {};
  Set<String> _presentedPopupIds = const {};
  Set<String> _hiddenCardIds = const {};
  Future<void>? _refreshFuture;
  Timer? _timeTransitionTimer;
  bool _isReadyForPopupPresentation = false;

  @override
  List<Announcement> get announcements => List<Announcement>.unmodifiable(
    _all.where((announcement) => announcement.isActiveAt(_now())),
  );

  @override
  List<Announcement> get notificationHistory => List<Announcement>.unmodifiable(
    _all.where((announcement) => announcement.isVisibleAt(_now())),
  );

  @override
  bool get isReadyForPopupPresentation => _isReadyForPopupPresentation;

  @override
  bool isExpired(Announcement announcement) => announcement.isExpiredAt(_now());

  @override
  List<Announcement> get discoverCardAnnouncements =>
      List<Announcement>.unmodifiable(
        announcements.where(
          (announcement) =>
              announcement.showsAsCard &&
              !_hiddenCardIds.contains(announcement.id),
        ),
      );

  @override
  Announcement? get latestDiscoverCard {
    final visibleCards = discoverCardAnnouncements;
    return visibleCards.isEmpty ? null : visibleCards.first;
  }

  @override
  bool isHiddenFromDiscover(Announcement announcement) =>
      _hiddenCardIds.contains(announcement.id);

  @override
  Announcement? get nextPopupToPresent {
    for (final announcement in announcements) {
      if (announcement.showsAsPopup &&
          !_presentedPopupIds.contains(announcement.id)) {
        return announcement;
      }
    }
    return null;
  }

  @override
  int get unreadCount => announcements
      .where((announcement) => !_readIds.contains(announcement.id))
      .length;

  @override
  bool isRead(Announcement announcement) => _readIds.contains(announcement.id);

  @override
  Future<void> refresh() => _refreshFuture ??= _refresh().whenComplete(() {
    _refreshFuture = null;
  });

  Future<void> _refresh() async {
    _isReadyForPopupPresentation = false;
    final storedState = await _store.load();
    _readIds = storedState.readIds.toSet();
    _presentedPopupIds = storedState.presentedPopupIds.toSet();
    _hiddenCardIds = storedState.hiddenCardIds.toSet();

    final cached = storedState.cachedManifest;
    final cachedAnnouncements = cached == null
        ? null
        : parseAnnouncementManifest(cached);
    if (cachedAnnouncements != null) {
      _all = cachedAnnouncements;
      _scheduleNextTimeTransition();
      notifyListeners();
    }

    final source = await _remoteSource.loadManifest();
    if (source != null) {
      final remoteAnnouncements = parseAnnouncementManifest(source);
      if (remoteAnnouncements != null) {
        _all = remoteAnnouncements;
        await _store.saveCachedManifest(source);
        _scheduleNextTimeTransition();
      }
    }

    _isReadyForPopupPresentation = true;
    notifyListeners();
  }

  @override
  Future<void> markRead(Announcement announcement) async {
    if (!_readIds.add(announcement.id)) {
      return;
    }
    await _store.saveReadIds(_readIds);
    notifyListeners();
  }

  @override
  Future<void> markAllRead() async {
    var changed = false;
    for (final announcement in announcements) {
      changed = _readIds.add(announcement.id) || changed;
    }
    if (!changed) {
      return;
    }
    await _store.saveReadIds(_readIds);
    notifyListeners();
  }

  @override
  Future<void> markPopupPresented(Announcement announcement) async {
    final readChanged = _readIds.add(announcement.id);
    final presentedChanged = _presentedPopupIds.add(announcement.id);
    if (!readChanged && !presentedChanged) {
      return;
    }
    await Future.wait([
      _store.saveReadIds(_readIds),
      _store.savePresentedPopupIds(_presentedPopupIds),
    ]);
    notifyListeners();
  }

  @override
  Future<void> hideCardFromDiscover(Announcement announcement) async {
    if (!announcement.showsAsCard || !_hiddenCardIds.add(announcement.id)) {
      return;
    }
    await _persistHiddenCardIds();
    notifyListeners();
  }

  @override
  Future<void> hideAllCardsFromDiscover() async {
    var changed = false;
    for (final announcement in announcements) {
      if (announcement.showsAsCard) {
        changed = _hiddenCardIds.add(announcement.id) || changed;
      }
    }
    if (!changed) {
      return;
    }
    await _persistHiddenCardIds();
    notifyListeners();
  }

  @override
  Future<void> showCardInDiscover(Announcement announcement) async {
    if (!_hiddenCardIds.remove(announcement.id)) {
      return;
    }
    await _persistHiddenCardIds();
    notifyListeners();
  }

  Future<void> _persistHiddenCardIds() async {
    await _store.saveHiddenCardIds(_hiddenCardIds);
  }

  void _scheduleNextTimeTransition() {
    _timeTransitionTimer?.cancel();
    _timeTransitionTimer = null;
    if (!_scheduleTimeTransitions) {
      return;
    }

    final now = _now();
    DateTime? nextTransition;
    void consider(DateTime? candidate) {
      if (candidate == null || !candidate.isAfter(now)) {
        return;
      }
      if (nextTransition == null || candidate.isBefore(nextTransition!)) {
        nextTransition = candidate;
      }
    }

    for (final announcement in _all) {
      consider(announcement.visibleAt);
      consider(announcement.expiresAt);
    }
    final transition = nextTransition;
    if (transition == null) {
      return;
    }
    _timeTransitionTimer = Timer(transition.difference(now), () {
      notifyListeners();
      _scheduleNextTimeTransition();
    });
  }

  @override
  void dispose() {
    _timeTransitionTimer?.cancel();
    super.dispose();
  }
}

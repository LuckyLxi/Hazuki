import 'package:flutter/foundation.dart';

import 'announcement.dart';

abstract interface class AnnouncementController implements Listenable {
  List<Announcement> get announcements;
  List<Announcement> get notificationHistory;
  List<Announcement> get discoverCardAnnouncements;
  Announcement? get latestDiscoverCard;
  Announcement? get nextPopupToPresent;
  int get unreadCount;
  bool get isReadyForPopupPresentation;

  bool isExpired(Announcement announcement);
  bool isHiddenFromDiscover(Announcement announcement);
  bool isRead(Announcement announcement);

  Future<void> refresh();
  Future<void> markRead(Announcement announcement);
  Future<void> markAllRead();
  Future<void> markPopupPresented(Announcement announcement);
  Future<void> hideCardFromDiscover(Announcement announcement);
  Future<void> hideAllCardsFromDiscover();
  Future<void> showCardInDiscover(Announcement announcement);
}

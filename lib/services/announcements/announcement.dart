enum AnnouncementLevel { normal, important }

enum AnnouncementPresentation { card, popup }

sealed class AnnouncementContentBlock {
  const AnnouncementContentBlock();
}

class AnnouncementTextBlock extends AnnouncementContentBlock {
  const AnnouncementTextBlock(this.text);

  final String text;
}

class AnnouncementImageBlock extends AnnouncementContentBlock {
  const AnnouncementImageBlock({
    required this.url,
    this.width,
    this.height,
    this.caption,
  });

  final String url;
  final double? width;
  final double? height;
  final String? caption;

  double? get aspectRatio {
    final blockWidth = width;
    final blockHeight = height;
    if (blockWidth == null || blockHeight == null || blockHeight <= 0) {
      return null;
    }
    return blockWidth / blockHeight;
  }
}

class AnnouncementLinkBlock extends AnnouncementContentBlock {
  const AnnouncementLinkBlock({required this.label, required this.url});

  final String label;
  final String url;
}

class Announcement {
  const Announcement({
    required this.id,
    required this.level,
    required this.presentation,
    required this.title,
    required this.publishedAt,
    required this.content,
    this.visibleAt,
    this.expiresAt,
  });

  final String id;
  final AnnouncementLevel level;
  final Set<AnnouncementPresentation> presentation;
  final String title;
  final DateTime publishedAt;
  final DateTime? visibleAt;
  final DateTime? expiresAt;
  final List<AnnouncementContentBlock> content;

  bool get showsAsCard => presentation.contains(AnnouncementPresentation.card);

  bool get showsAsPopup =>
      presentation.contains(AnnouncementPresentation.popup);

  bool isVisibleAt(DateTime time) {
    final visibilityTime = visibleAt;
    return visibilityTime == null || !visibilityTime.isAfter(time);
  }

  bool isExpiredAt(DateTime time) {
    final expiry = expiresAt;
    return expiry != null && !expiry.isAfter(time);
  }

  bool isActiveAt(DateTime time) {
    return isVisibleAt(time) && !isExpiredAt(time);
  }
}

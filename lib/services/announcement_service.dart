import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../shared/preferences/hazuki_preference_keys.dart';
import 'network/hazuki_network.dart';
import 'software_update/software_update_service.dart';

const _githubAnnouncementManifestUrl =
    'https://raw.githubusercontent.com/LuckyLxi/Hazuki/main/announcement.json';
const _jsDelivrAnnouncementManifestUrl =
    'https://cdn.jsdelivr.net/gh/LuckyLxi/Hazuki@main/announcement.json';
const _ghProxyBaseUrl = 'https://ghproxy.net/';

String resolveAnnouncementManifestUrl(SoftwareUpdateSource source) {
  return switch (source) {
    SoftwareUpdateSource.jsDelivr => _jsDelivrAnnouncementManifestUrl,
    SoftwareUpdateSource.github => _githubAnnouncementManifestUrl,
    SoftwareUpdateSource.ghproxy =>
      '$_ghProxyBaseUrl$_githubAnnouncementManifestUrl',
  };
}

typedef AnnouncementRemoteLoader = Future<String?> Function();

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

@visibleForTesting
List<Announcement>? parseAnnouncementManifest(String source) {
  final trimmed = source.trim();
  if (trimmed.isEmpty) {
    return const <Announcement>[];
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(trimmed);
  } on FormatException {
    return null;
  }

  final Object? entries = switch (decoded) {
    List<Object?>() => decoded,
    Map<Object?, Object?>() => decoded['announcements'],
    _ => null,
  };
  if (entries is! List) {
    return null;
  }

  final announcements = <Announcement>[];
  final ids = <String>{};
  for (final entry in entries) {
    if (entry is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(entry);
    final id = _nonEmptyString(map['id']);
    final title = _nonEmptyString(map['title']);
    final publishedAt = DateTime.tryParse(
      _nonEmptyString(map['publishedAt']) ?? '',
    );
    final level = _parseAnnouncementLevel(map['level']);
    if (id == null ||
        title == null ||
        publishedAt == null ||
        level == null ||
        !ids.add(id)) {
      continue;
    }

    final presentation = _parseAnnouncementPresentation(
      map['presentation'],
      level,
    );
    if (presentation == null) {
      continue;
    }

    final visibleRaw = _nonEmptyString(map['visibleAt']);
    final visibleAt = visibleRaw == null ? null : DateTime.tryParse(visibleRaw);
    if (visibleRaw != null && visibleAt == null) {
      continue;
    }

    final expiresRaw = _nonEmptyString(map['expiresAt']);
    final expiresAt = expiresRaw == null ? null : DateTime.tryParse(expiresRaw);
    if (expiresRaw != null && expiresAt == null) {
      continue;
    }

    final content = _parseContent(map['content']);
    if (content.isEmpty) {
      continue;
    }
    announcements.add(
      Announcement(
        id: id,
        level: level,
        presentation: presentation,
        title: title,
        publishedAt: publishedAt,
        visibleAt: visibleAt,
        expiresAt: expiresAt,
        content: List<AnnouncementContentBlock>.unmodifiable(content),
      ),
    );
  }
  announcements.sort((a, b) => b.publishedAt.compareTo(a.publishedAt));
  return List<Announcement>.unmodifiable(announcements);
}

String? _nonEmptyString(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

AnnouncementLevel? _parseAnnouncementLevel(Object? value) {
  return switch (_nonEmptyString(value)?.toLowerCase()) {
    'normal' || 'low' => AnnouncementLevel.normal,
    'important' || 'high' => AnnouncementLevel.important,
    _ => null,
  };
}

Set<AnnouncementPresentation>? _parseAnnouncementPresentation(
  Object? value,
  AnnouncementLevel level,
) {
  if (value == null) {
    return Set<AnnouncementPresentation>.unmodifiable(
      level == AnnouncementLevel.normal
          ? const {AnnouncementPresentation.card}
          : const {AnnouncementPresentation.popup},
    );
  }
  if (value is! List || value.isEmpty) {
    return null;
  }
  final presentation = <AnnouncementPresentation>{};
  for (final entry in value) {
    final parsed = switch (_nonEmptyString(entry)?.toLowerCase()) {
      'card' => AnnouncementPresentation.card,
      'popup' => AnnouncementPresentation.popup,
      _ => null,
    };
    if (parsed == null) {
      return null;
    }
    presentation.add(parsed);
  }
  return Set<AnnouncementPresentation>.unmodifiable(presentation);
}

List<AnnouncementContentBlock> _parseContent(Object? raw) {
  if (raw is String) {
    final text = raw.trim();
    return text.isEmpty ? const [] : [AnnouncementTextBlock(text)];
  }
  if (raw is! List) {
    return const [];
  }

  final blocks = <AnnouncementContentBlock>[];
  for (final entry in raw) {
    if (entry is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(entry);
    switch (_nonEmptyString(map['type'])?.toLowerCase()) {
      case 'text':
        final text = _nonEmptyString(map['text']);
        if (text != null) {
          blocks.add(AnnouncementTextBlock(text));
        }
      case 'image':
        final url = _validWebUrl(map['url'], requireHttps: true);
        if (url != null) {
          blocks.add(
            AnnouncementImageBlock(
              url: url,
              width: _positiveDouble(map['width']),
              height: _positiveDouble(map['height']),
              caption: _nonEmptyString(map['caption']),
            ),
          );
        }
      case 'link':
        final label = _nonEmptyString(map['label']);
        final url = _validWebUrl(map['url']);
        if (label != null && url != null) {
          blocks.add(AnnouncementLinkBlock(label: label, url: url));
        }
    }
  }
  return blocks;
}

String? _validWebUrl(Object? value, {bool requireHttps = false}) {
  final raw = _nonEmptyString(value);
  final uri = raw == null ? null : Uri.tryParse(raw);
  if (uri == null || !uri.hasAuthority) {
    return null;
  }
  if (requireHttps
      ? uri.scheme != 'https'
      : !{'http', 'https'}.contains(uri.scheme)) {
    return null;
  }
  return uri.toString();
}

double? _positiveDouble(Object? value) {
  final parsed = value is num ? value.toDouble() : double.tryParse('$value');
  return parsed != null && parsed > 0 ? parsed : null;
}

class AnnouncementService extends ChangeNotifier {
  AnnouncementService({
    HazukiNetworkClient? client,
    AnnouncementRemoteLoader? loadRemote,
    Future<SharedPreferences> Function()? loadPreferences,
    DateTime Function()? now,
  }) : _loadRemote =
           loadRemote ?? _defaultRemoteLoader(client ?? _createClient()),
       _loadPreferences = loadPreferences ?? SharedPreferences.getInstance,
       _now = now ?? DateTime.now,
       _scheduleTimeTransitions = now == null;

  final AnnouncementRemoteLoader _loadRemote;
  final Future<SharedPreferences> Function() _loadPreferences;
  final DateTime Function() _now;
  final bool _scheduleTimeTransitions;
  List<Announcement> _all = const [];
  Set<String> _readIds = const {};
  Set<String> _presentedPopupIds = const {};
  Set<String> _hiddenCardIds = const {};
  Future<void>? _refreshFuture;
  Timer? _timeTransitionTimer;

  List<Announcement> get announcements => List<Announcement>.unmodifiable(
    _all.where((announcement) => announcement.isActiveAt(_now())),
  );

  List<Announcement> get notificationHistory => List<Announcement>.unmodifiable(
    _all.where((announcement) => announcement.isVisibleAt(_now())),
  );

  bool isExpired(Announcement announcement) => announcement.isExpiredAt(_now());

  List<Announcement> get discoverCardAnnouncements =>
      List<Announcement>.unmodifiable(
        announcements.where(
          (announcement) =>
              announcement.showsAsCard &&
              !_hiddenCardIds.contains(announcement.id),
        ),
      );

  Announcement? get latestDiscoverCard {
    final visibleCards = discoverCardAnnouncements;
    return visibleCards.isEmpty ? null : visibleCards.first;
  }

  bool isHiddenFromDiscover(Announcement announcement) =>
      _hiddenCardIds.contains(announcement.id);

  Announcement? get nextPopupToPresent {
    for (final announcement in announcements) {
      if (announcement.showsAsPopup &&
          !_presentedPopupIds.contains(announcement.id)) {
        return announcement;
      }
    }
    return null;
  }

  int get unreadCount => announcements
      .where((announcement) => !_readIds.contains(announcement.id))
      .length;

  bool isRead(Announcement announcement) => _readIds.contains(announcement.id);

  Future<void> refresh() => _refreshFuture ??= _refresh().whenComplete(() {
    _refreshFuture = null;
  });

  Future<void> _refresh() async {
    final prefs = await _loadPreferences();
    _readIds =
        prefs.getStringList(hazukiAnnouncementReadIdsPreferenceKey)?.toSet() ??
        <String>{};
    _presentedPopupIds =
        prefs
            .getStringList(hazukiAnnouncementPresentedIdsPreferenceKey)
            ?.toSet() ??
        <String>{};
    _hiddenCardIds =
        prefs
            .getStringList(hazukiAnnouncementHiddenCardIdsPreferenceKey)
            ?.toSet() ??
        <String>{};

    final cached = prefs.getString(hazukiAnnouncementCachePreferenceKey);
    final cachedAnnouncements = cached == null
        ? null
        : parseAnnouncementManifest(cached);
    if (cachedAnnouncements != null) {
      _all = cachedAnnouncements;
      _scheduleNextTimeTransition();
      notifyListeners();
    }

    try {
      final source = await _loadRemote();
      if (source == null) {
        return;
      }
      final remoteAnnouncements = parseAnnouncementManifest(source);
      if (remoteAnnouncements == null) {
        return;
      }
      _all = remoteAnnouncements;
      await prefs.setString(hazukiAnnouncementCachePreferenceKey, source);
      _scheduleNextTimeTransition();
      notifyListeners();
    } on DioException {
      // Cached announcements remain available when the remote is unreachable.
    }
  }

  Future<void> markRead(Announcement announcement) async {
    if (!_readIds.add(announcement.id)) {
      return;
    }
    final prefs = await _loadPreferences();
    await prefs.setStringList(
      hazukiAnnouncementReadIdsPreferenceKey,
      _readIds.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> markAllRead() async {
    var changed = false;
    for (final announcement in announcements) {
      changed = _readIds.add(announcement.id) || changed;
    }
    if (!changed) {
      return;
    }
    final prefs = await _loadPreferences();
    await prefs.setStringList(
      hazukiAnnouncementReadIdsPreferenceKey,
      _readIds.toList(growable: false),
    );
    notifyListeners();
  }

  Future<void> markPopupPresented(Announcement announcement) async {
    final readChanged = _readIds.add(announcement.id);
    final presentedChanged = _presentedPopupIds.add(announcement.id);
    if (!readChanged && !presentedChanged) {
      return;
    }
    final prefs = await _loadPreferences();
    await Future.wait([
      prefs.setStringList(
        hazukiAnnouncementReadIdsPreferenceKey,
        _readIds.toList(growable: false),
      ),
      prefs.setStringList(
        hazukiAnnouncementPresentedIdsPreferenceKey,
        _presentedPopupIds.toList(growable: false),
      ),
    ]);
    notifyListeners();
  }

  Future<void> hideCardFromDiscover(Announcement announcement) async {
    if (!announcement.showsAsCard || !_hiddenCardIds.add(announcement.id)) {
      return;
    }
    await _persistHiddenCardIds();
    notifyListeners();
  }

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

  Future<void> showCardInDiscover(Announcement announcement) async {
    if (!_hiddenCardIds.remove(announcement.id)) {
      return;
    }
    await _persistHiddenCardIds();
    notifyListeners();
  }

  Future<void> _persistHiddenCardIds() async {
    final prefs = await _loadPreferences();
    await prefs.setStringList(
      hazukiAnnouncementHiddenCardIdsPreferenceKey,
      _hiddenCardIds.toList(growable: false),
    );
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

HazukiNetworkClient _createClient() {
  return HazukiNetworkClient(
    dio: createHazukiDio(
      baseOptions: BaseOptions(
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 3),
        responseType: ResponseType.plain,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    ),
  );
}

AnnouncementRemoteLoader _defaultRemoteLoader(HazukiNetworkClient client) {
  return () async {
    final source = await loadSoftwareUpdateSourcePreference();
    final manifestUrl = resolveAnnouncementManifestUrl(source);
    final cacheBuster = DateTime.now().millisecondsSinceEpoch;
    final response = await client.get<String>(
      '$manifestUrl?ts=$cacheBuster',
      options: Options(headers: const {'Cache-Control': 'no-cache'}),
    );
    return response.data ?? '';
  };
}

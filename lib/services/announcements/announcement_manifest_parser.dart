import 'dart:convert';

import 'announcement.dart';

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

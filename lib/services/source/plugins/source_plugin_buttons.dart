import 'source_plugin_exception.dart';

/// Existing application slots; plugins choose visibility without defining UI.
enum SourcePluginButtonLocation {
  homeProfile,
  comicDetailInfo,
  comicDetailTabs,
  reading,
  reader,
  other,
  advanced,
}

const _buttonLocations = <String, Set<SourcePluginButtonLocation>>{
  'checkIn': {SourcePluginButtonLocation.homeProfile},
  'autoCheckIn': {SourcePluginButtonLocation.other},
  'copyComicId': {SourcePluginButtonLocation.comicDetailInfo},
  'relatedComics': {SourcePluginButtonLocation.comicDetailTabs},
  'imageQuality': {
    SourcePluginButtonLocation.reading,
    SourcePluginButtonLocation.reader,
  },
  'resetDeviceInfo': {SourcePluginButtonLocation.advanced},
};

class SourcePluginButton {
  const SourcePluginButton({
    required this.id,
    required this.location,
    this.action,
    this.title,
    this.subtitle,
    this.successMessage,
  });

  final String id;
  final SourcePluginButtonLocation location;
  final String? action;
  final Object? title;
  final Object? subtitle;
  final Object? successMessage;

  static List<SourcePluginButton> parseList(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const SourcePluginException('plugin_invalid_buttons');
    }
    final seen = <(String, SourcePluginButtonLocation)>{};
    // Retired like-button declarations are ignored for installed API v1 plugins.
    // Like visibility and its fixed position come from comic.likeComic instead.
    return value
        .where((item) => item is! Map || item['id'] != 'comicLike')
        .map((item) {
          if (item is! Map || item['id'] is! String) {
            throw const SourcePluginException('plugin_invalid_buttons');
          }
          final id = item['id'] as String;
          final location = SourcePluginButtonLocation.values
              .where((location) => location.name == item['location'])
              .firstOrNull;
          if (location == null ||
              _buttonLocations[id]?.contains(location) != true) {
            throw SourcePluginException('plugin_invalid_button_location', id);
          }
          if (!seen.add((id, location))) {
            throw SourcePluginException('plugin_duplicate_button', id);
          }
          final action = item['action'];
          if ((action != null &&
                  (action is! String ||
                      action.isEmpty ||
                      id != 'resetDeviceInfo')) ||
              (id == 'resetDeviceInfo' && action == null)) {
            throw SourcePluginException('plugin_invalid_button_action', id);
          }
          return SourcePluginButton(
            id: id,
            location: location,
            action: action as String?,
            title: item['title'],
            subtitle: item['subtitle'],
            successMessage: item['successMessage'],
          );
        })
        .toList(growable: false);
  }
}

SourcePluginButton? sourcePluginButton(
  Map<String, dynamic> presentation,
  String id,
  SourcePluginButtonLocation location,
) => SourcePluginButton.parseList(
  presentation['buttons'],
).where((button) => button.id == id && button.location == location).firstOrNull;

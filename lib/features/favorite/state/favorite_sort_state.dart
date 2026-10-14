import 'package:hazuki/models/hazuki_models.dart';

/// Sort workflows can read the current mode and update the selected order.
abstract interface class FavoriteSortState {
  FavoritePageMode get mode;
  String get favoriteSortOrder;
  set favoriteSortOrder(String value);
}

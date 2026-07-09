import 'package:flutter/widgets.dart';

import 'package:hazuki/models/hazuki_models.dart';

typedef HistoryFavoriteRequested =
    Future<void> Function(BuildContext context, ExploreComic comic);

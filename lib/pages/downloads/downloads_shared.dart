import 'package:flutter/widgets.dart';

import '../../services/manga_download_service.dart';

typedef DownloadedComicReaderPageBuilder =
    Widget Function(DownloadedMangaComic comic, DownloadedMangaChapter chapter);

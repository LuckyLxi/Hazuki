import 'package:flutter/widgets.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

typedef DownloadedComicReaderPageBuilder =
    Widget Function(DownloadedMangaComic comic, DownloadedMangaChapter chapter);

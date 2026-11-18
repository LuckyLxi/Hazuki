import 'package:flutter/widgets.dart';
import 'package:hazuki/services/manga_download/manga_download_models.dart';

/// 从已下载漫画的章节打开阅读器的构建签名。
typedef DownloadedComicReaderPageBuilder =
    Widget Function(DownloadedMangaComic comic, DownloadedMangaChapter chapter);

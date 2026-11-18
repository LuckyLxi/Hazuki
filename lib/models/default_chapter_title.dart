/// 来源未提供章节名时写入的占位标题，由界面层替换为本地化文案。
const hazukiDefaultChapterTitleToken = '__default_chapter_1__';

bool isHazukiDefaultChapterTitle(String rawTitle) {
  return rawTitle.trim() == hazukiDefaultChapterTitleToken;
}

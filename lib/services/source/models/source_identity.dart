const hazukiDefaultSourceKey = 'jm';

bool isHazukiJmSourceKey(String sourceKey) {
  return sourceKey.trim() == hazukiDefaultSourceKey;
}

bool isHazukiCopyMangaSourceKey(String sourceKey) {
  return sourceKey.trim() == 'copy_manga';
}

bool isHazukiPicacgSourceKey(String sourceKey) {
  return sourceKey.trim() == 'picacg';
}

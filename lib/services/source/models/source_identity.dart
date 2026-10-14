// Compatibility identity for legacy records, downloads and edited scripts.
const hazukiDefaultSourceKey = 'jm';

bool isHazukiJmSourceKey(String sourceKey) {
  return sourceKey.trim() == hazukiDefaultSourceKey;
}

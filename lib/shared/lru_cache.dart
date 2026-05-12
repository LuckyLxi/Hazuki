class LruCache<K, V> {
  LruCache({required this.maxSize}) : assert(maxSize > 0);

  final int maxSize;
  final Map<K, V> _entries = <K, V>{};

  V? get(K key) {
    if (!_entries.containsKey(key)) return null;
    final value = _entries.remove(key) as V;
    _entries[key] = value;
    return value;
  }

  void put(K key, V value) {
    _entries.remove(key);
    _entries[key] = value;
    while (_entries.length > maxSize) {
      _entries.remove(_entries.keys.first);
    }
  }

  bool contains(K key) => _entries.containsKey(key);

  void remove(K key) => _entries.remove(key);

  int get length => _entries.length;

  Iterable<K> get keys => _entries.keys;
}

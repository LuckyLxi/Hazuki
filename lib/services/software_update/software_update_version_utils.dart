String normalizeSoftwareVersion(String version) {
  return version.trim().replaceFirst(RegExp(r'^[vV]'), '');
}

bool isSoftwareVersionGreater(String a, String b) {
  final pa = _parseSegments(a);
  final pb = _parseSegments(b);
  final len = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < len; i++) {
    final va = i < pa.length ? pa[i] : 0;
    final vb = i < pb.length ? pb[i] : 0;
    if (va > vb) {
      return true;
    }
    if (va < vb) {
      return false;
    }
  }
  return false;
}

List<int> _parseSegments(String version) {
  final cleaned = version.trim().split('+').first.split('-').first;
  return cleaned.split('.').map((segment) {
    final match = RegExp(r'\d+').firstMatch(segment);
    return int.tryParse(match?.group(0) ?? '0') ?? 0;
  }).toList();
}

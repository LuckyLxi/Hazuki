import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/features/search/support/search_shared.dart';

void main() {
  test('normalizes direct comic id keywords without extracting from prose', () {
    expect(normalizeDirectComicIdKeyword('12345'), '12345');
    expect(normalizeDirectComicIdKeyword(' JM12345 '), 'jm12345');
    expect(normalizeDirectComicIdKeyword('abc123def'), isNull);
    expect(normalizeDirectComicIdKeyword('1'), isNull);
  });

  test('aggregate search routes direct comic ids through JM', () {
    expect(
      directComicIdSourceKey(
        aggregateSearchEnabled: true,
        activeSourceKey: 'copy_manga',
      ),
      jmSearchSourceKey,
    );
    expect(
      directComicIdSourceKey(
        aggregateSearchEnabled: false,
        activeSourceKey: 'copy_manga',
      ),
      isNull,
    );
  });
}

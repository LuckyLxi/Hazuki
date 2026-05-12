import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/software_update/software_update_version_utils.dart';

void main() {
  group('normalizeSoftwareVersion', () {
    test('strips leading v / V', () {
      expect(normalizeSoftwareVersion('v1.2.3'), '1.2.3');
      expect(normalizeSoftwareVersion('V1.2.3'), '1.2.3');
    });

    test('trims whitespace', () {
      expect(normalizeSoftwareVersion('  v1.0.0  '), '1.0.0');
    });

    test('leaves non-prefixed versions untouched', () {
      expect(normalizeSoftwareVersion('1.2.3'), '1.2.3');
    });

    test('only strips a single leading v', () {
      expect(normalizeSoftwareVersion('vv1.2.3'), 'v1.2.3');
    });
  });

  group('isSoftwareVersionGreater', () {
    test('returns false for equal versions', () {
      expect(isSoftwareVersionGreater('1.0.0', '1.0.0'), isFalse);
    });

    test('compares numeric segments', () {
      expect(isSoftwareVersionGreater('1.2.0', '1.1.9'), isTrue);
      expect(isSoftwareVersionGreater('1.1.9', '1.2.0'), isFalse);
      expect(isSoftwareVersionGreater('2.0.0', '1.99.99'), isTrue);
    });

    test('treats missing trailing segments as zero', () {
      expect(isSoftwareVersionGreater('1.1', '1.0.5'), isTrue);
      expect(isSoftwareVersionGreater('1.0', '1.0.0'), isFalse);
      expect(isSoftwareVersionGreater('1.0.0', '1.0'), isFalse);
    });

    test('ignores build / pre-release suffixes', () {
      expect(isSoftwareVersionGreater('1.1.0+5', '1.1.0+1'), isFalse);
      expect(isSoftwareVersionGreater('1.2.0-beta', '1.1.0'), isTrue);
    });

    test('extracts numeric portion from mixed segments', () {
      expect(isSoftwareVersionGreater('1.2a', '1.1'), isTrue);
      expect(isSoftwareVersionGreater('1.10.0', '1.9.0'), isTrue);
    });

    test('handles empty inputs as zero-versions', () {
      expect(isSoftwareVersionGreater('', ''), isFalse);
      expect(isSoftwareVersionGreater('1.0.0', ''), isTrue);
    });
  });
}

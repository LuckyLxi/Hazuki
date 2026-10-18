import 'package:flutter_test/flutter_test.dart';
import 'package:hazuki/services/source/runtime/source_cookie_store.dart';

void main() {
  late List<SourceCookie> saved;
  late SourceCookieStore store;
  setUp(() {
    saved = [];
    store = SourceCookieStore(
      loadCookies: () => List.of(saved),
      saveCookies: (cookies) async {
        saved = cookies;
      },
    );
  });
  test('host, path boundary, HTTPS and metadata survive persistence', () async {
    final cookie = SourceCookie.parseSetCookie(
      'sid=secret; Path=/account; Secure; HttpOnly; SameSite=None; Max-Age=600',
      'https://site.example/login',
    )!;
    await store.set('https://site.example/login', [
      SourceCookie.fromMap(cookie.toMap()),
    ]);
    expect(
      store.buildHeader('https://site.example/account/profile'),
      'sid=secret',
    );
    for (final url in [
      'http://site.example/account',
      'https://sub.site.example/account',
      'https://site.example/accounting',
      'https://evilsite.example/account',
    ]) {
      expect(store.buildHeader(url), isNull);
    }
    expect(saved.single.httpOnly, isTrue);
    expect(saved.single.sameSite, 'none');
    expect(saved.single.hostOnly, isTrue);
  });
  test(
    'domain cookies, same-name paths, deletion and expiry precedence',
    () async {
      await store.saveFromHeaders('https://site.example/account/login', {
        'set-cookie': [
          'sid=root; Domain=site.example; Path=/',
          'sid=account; Domain=.site.example; Path=/account; Max-Age=300; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
          'bad=outside; Domain=other.example; Path=/',
        ],
      });
      expect(
        store.buildHeader('https://sub.site.example/account/me'),
        'sid=account; sid=root',
      );
      expect(saved.length, 2);
      await store.saveFromHeaders('https://site.example/account/login', {
        'set-cookie': [
          'sid=deleted; Domain=.site.example; Path=/account; Max-Age=0',
        ],
      });
      expect(store.buildHeader('https://site.example/account/me'), 'sid=root');
    },
  );
  test('old records retain host scope and RFC dates are parsed', () {
    final old = SourceCookie.fromMap({
      'name': 'sid',
      'value': 'v',
      'domain': 'site.example',
      'path': '/',
    });
    expect(old.matches(Uri.parse('https://child.site.example/')), isFalse);
    expect(
      SourceCookie.parseSetCookie(
        'sid=v; Expires=Wed, 21 Oct 2015 07:28:00 GMT',
        'https://site.example/',
      )!.isExpired(DateTime.now().millisecondsSinceEpoch),
      isTrue,
    );
  });
  test(
    'Android canonical export preserves host-only domains unlike Set-Cookie',
    () {
      const raw = 'sid=mock; domain=site.example; path=/; secure; httponly';
      final exported = SourceCookie.parseSetCookie(
        raw,
        'https://site.example/',
        browserSnapshot: true,
      )!;
      expect(exported.hostOnly, isTrue);
      expect(exported.matches(Uri.parse('https://sub.site.example/')), isFalse);
      expect(
        SourceCookie.parseSetCookie(raw, 'https://site.example/')!.hostOnly,
        isFalse,
      );
    },
  );
}

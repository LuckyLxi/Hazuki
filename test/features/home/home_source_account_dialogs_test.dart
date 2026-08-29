import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hazuki/l10n/app_localizations.dart';
import 'package:hazuki/services/source/gateways/source_image_gateways.dart';
import 'package:hazuki/shared/liquid_glass_support.dart';
import 'package:hazuki/shared/source_account/source_account_dialogs.dart';
import 'package:hazuki/widgets/source_image_gateway_scope.dart';

void main() {
  testWidgets('profile glass card stays clipped while closing', (tester) async {
    await tester.runAsync(HazukiLiquidGlass.initialize);

    await tester.pumpWidget(
      SourceImageGatewayScope(
        gateway: const _EmptyImageGateway(),
        child: HazukiLiquidGlass.wrap(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) {
                return Scaffold(
                  body: TextButton(
                    onPressed: () => showHomeAvatarCard(
                      context,
                      avatarUrl: '',
                      username: 'Hazuki',
                      firstUseText: 'First used today',
                      onLogoutTap: () {},
                      onRequestSaveAvatar: () async {},
                    ),
                    child: const Text('Open'),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();

    const cardKey = ValueKey('home-profile-liquid-glass-card');
    final card = find.byKey(cardKey);
    expect(card, findsOneWidget);
    expect(
      find.ancestor(of: card, matching: find.byType(ClipRSuperellipse)),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 80));

    expect(card, findsOneWidget);
    expect(
      find.ancestor(of: card, matching: find.byType(ClipRSuperellipse)),
      findsOneWidget,
    );
  });
}

class _EmptyImageGateway implements SourceImageGateway {
  const _EmptyImageGateway();

  @override
  String get activeSourceKey => 'test';

  @override
  Uint8List? peekImageBytesFromMemory(String url, {String sourceKey = ''}) {
    return null;
  }

  @override
  Future<Uint8List> downloadImageBytes(
    String url, {
    String comicId = '',
    String epId = '',
    bool keepInMemory = false,
    bool useDiskCache = true,
    bool priority = false,
    String sourceKey = '',
  }) {
    throw StateError('No image download expected in this test.');
  }
}

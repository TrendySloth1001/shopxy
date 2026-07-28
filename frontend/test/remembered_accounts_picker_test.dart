// The login-screen account picker.
//
// Worth pinning because this widget's failure mode is silence: it renders
// SizedBox.shrink() on an empty list, so "nothing on the login screen" is what
// both a working-but-empty picker and a broken one look like. That ambiguity is
// exactly why the missing remember_tokens table went undiagnosed — the feature
// appeared not to exist.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy/features/auth/presentation/widgets/remembered_accounts_sheet.dart';
import 'package:shopxy/l10n/app_localizations.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  late Map<String, String> store;

  setUp(() {
    store = {};
    binding.defaultBinaryMessenger.setMockMethodCallHandler(secure, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      switch (call.method) {
        case 'write':
          store[args['key'] as String] = args['value'] as String;
          return null;
        case 'read':
          return store[args['key'] as String];
        case 'delete':
          store.remove(args['key'] as String);
          return null;
        case 'containsKey':
          return store.containsKey(args['key'] as String);
        default:
          return null;
      }
    });
  });
  tearDown(() {
    binding.defaultBinaryMessenger.setMockMethodCallHandler(secure, null);
  });

  /// Seeds the keychain the way a real sign-in would.
  void remember(
    List<({String id, String name, String email})> accounts, {
    String? avatarUrl,
  }) {
    store['remembered_accounts'] = jsonEncode([
      for (final a in accounts)
        {
          'id': a.id,
          'name': a.name,
          'email': a.email,
          'avatarUrl': avatarUrl,
          'token': 'remember-${a.id}',
        },
    ]);
  }

  Widget harness() {
    final tm = TokenManager();
    final api = ApiClient(
      tm,
      httpClient: MockClient((_) async => http.Response('{}', 200)),
    );
    return ChangeNotifierProvider<AuthProvider>(
      create: (_) => AuthProvider(AuthRemoteDataSource(api), tm),
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: RememberedAccountsButton()),
      ),
    );
  }

  testWidgets('nothing remembered → the picker takes no space', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
  });

  testWidgets('one account → the pill names them', (tester) async {
    remember([(id: '1', name: 'Nikhil Kumawat', email: 'nikhil@shop.test')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Continue as Nikhil Kumawat'), findsOneWidget);
  });

  testWidgets('several accounts → the pill opens a sheet listing them', (
    tester,
  ) async {
    remember([
      (id: '1', name: 'Nikhil Kumawat', email: 'nikhil@shop.test'),
      (id: '2', name: 'Asha Traders', email: 'asha@shop.test'),
    ]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    // Collapsed: one pill, not a list — the form stays above the fold.
    expect(find.text('Logged in accounts'), findsOneWidget);
    expect(find.text('Asha Traders'), findsNothing);

    await tester.tap(find.text('Logged in accounts'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an account'), findsOneWidget);
    expect(find.text('Nikhil Kumawat'), findsOneWidget);
    expect(find.text('Asha Traders'), findsOneWidget);
    expect(find.text('asha@shop.test'), findsOneWidget);
    expect(find.text('Use another account'), findsOneWidget);
  });

  testWidgets('a nameless account falls back to its email, not a blank row', (
    tester,
  ) async {
    remember([(id: '1', name: '', email: 'nameless@shop.test')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('Continue as nameless@shop.test'), findsOneWidget);
  });

  testWidgets('an avatar that fails to load shows the letter, not a blank disc', (
    tester,
  ) async {
    // A remembered account carries whatever avatar URL it was cached with, so
    // it 404s once that user changes their picture — and the login screen can
    // render before the network is reachable at all. Either way the circle must
    // not come out empty. (The test harness answers every image request with a
    // 400, which is exactly the failure being asserted.)
    remember([
      (id: '1', name: 'Nikhil Kumawat', email: 'nikhil@shop.test'),
    ], avatarUrl: '/images/gone.webp');
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('removing the last account closes the sheet', (tester) async {
    remember([(id: '1', name: 'Nikhil Kumawat', email: 'nikhil@shop.test')]);
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Continue as Nikhil Kumawat'));
    await tester.pumpAndSettle();
    expect(find.text('Choose an account'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove this account'));
    await tester.pumpAndSettle();

    expect(find.text('Choose an account'), findsNothing);
    // And the pill goes with it — there's nothing left to continue as.
    expect(find.text('Continue as Nikhil Kumawat'), findsNothing);
  });
}

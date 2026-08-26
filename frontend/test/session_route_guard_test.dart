import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shopxy/core/auth/session_route_guard.dart';
import 'package:shopxy/core/auth/token_manager.dart';
import 'package:shopxy/core/network/api_client.dart';
import 'package:shopxy/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy/features/auth/presentation/providers/auth_provider.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const secure = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    final store = <String, String>{};
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

  Future<AuthProvider> signedInProvider() async {
    final tm = TokenManager();
    await tm.saveTokens(accessToken: 'access', refreshToken: 'refresh');
    final api = ApiClient(
      tm,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"id":"1","email":"m@x.com","name":"M","role":"OWNER",'
          '"createdAt":"2026-01-01T00:00:00.000Z"}',
          200,
        ),
      ),
    );
    final auth = AuthProvider(AuthRemoteDataSource(api), tm);
    await auth.init();
    expect(auth.isAuthenticated, isTrue, reason: 'test setup');
    return auth;
  }

  Widget harness(AuthProvider auth) {
    return ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp(
        home: SessionRouteGuard(
          child: Consumer<AuthProvider>(
            builder: (_, a, _) =>
                Scaffold(body: Text(a.isAuthenticated ? 'shell' : 'login')),
          ),
        ),
      ),
    );
  }

  testWidgets('logging out from a pushed screen returns to login', (
    tester,
  ) async {
    final auth = await signedInProvider();
    await tester.pumpWidget(harness(auth));
    await tester.pumpAndSettle();
    expect(find.text('shell'), findsOneWidget);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('profile')),
      ),
    );
    await tester.pumpAndSettle();
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('settings'), findsOneWidget);

    await auth.logout();
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsNothing, reason: 'the reported bug');
    expect(find.text('profile'), findsNothing, reason: 'the whole stack goes');
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('an expiry deep in the app unwinds too, with no logout tap', (
    tester,
  ) async {
    final auth = await signedInProvider();
    await tester.pumpWidget(harness(auth));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();

    await auth.clearAuth();
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('an open sheet does not survive the logout', (tester) async {
    final auth = await signedInProvider();
    await tester.pumpWidget(harness(auth));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('shell'));
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => const Text('sheet'),
    );
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);

    await auth.logout();
    await tester.pumpAndSettle();

    expect(find.text('sheet'), findsNothing);
    expect(find.text('login'), findsOneWidget);
  });

  testWidgets('an ordinary profile refresh does NOT pop the stack', (
    tester,
  ) async {
    final auth = await signedInProvider();
    await tester.pumpWidget(harness(auth));
    await tester.pumpAndSettle();

    tester.state<NavigatorState>(find.byType(Navigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('settings')),
      ),
    );
    await tester.pumpAndSettle();

    await auth.refreshUser();
    await tester.pumpAndSettle();

    expect(find.text('settings'), findsOneWidget);
  });
}

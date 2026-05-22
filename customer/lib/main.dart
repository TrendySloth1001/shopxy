import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopxy_customer/core/app.dart';
import 'package:shopxy_customer/core/auth/token_manager.dart';
import 'package:shopxy_customer/core/network/api_client.dart';
import 'package:shopxy_customer/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:shopxy_customer/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopxy_customer/features/notifications/data/datasources/notifications_remote_data_source.dart';
import 'package:shopxy_customer/features/notifications/presentation/providers/notifications_provider.dart';
import 'package:shopxy_customer/features/shops/data/datasources/me_remote_data_source.dart';
import 'package:shopxy_customer/features/shops/presentation/providers/shops_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final tokenManager = TokenManager();
  await tokenManager.init();

  final apiClient = ApiClient(tokenManager);

  final authDs = AuthRemoteDataSource(apiClient);
  final notificationsDs = NotificationsRemoteDataSource(apiClient);
  final invitationsDs = InvitationsRemoteDataSource(apiClient);
  final meDs = MeRemoteDataSource(apiClient);

  final authProvider = AuthProvider(authDs, tokenManager);
  final notificationsProvider =
      NotificationsProvider(notificationsDs, invitationsDs);
  final shopsProvider = ShopsProvider(meDs);

  // Force re-login if the refresh fails and clear cached state.
  tokenManager.onUnauthorized = () {
    authProvider.clearAuth();
    notificationsProvider.reset();
    shopsProvider.reset();
  };

  // After login or app boot: prime the bell badge + pending invites so
  // the home screen can immediately surface a "you've been invited"
  // callout. Single listener for the app lifetime — doesn't leak.
  authProvider.addListener(() {
    if (authProvider.isAuthenticated) {
      notificationsProvider.refreshUnreadCount();
      notificationsProvider.loadIncoming(status: 'PENDING');
      shopsProvider.loadShops();
    } else {
      notificationsProvider.reset();
      shopsProvider.reset();
    }
  });

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
        ChangeNotifierProvider<NotificationsProvider>.value(
            value: notificationsProvider),
        ChangeNotifierProvider<ShopsProvider>.value(value: shopsProvider),
      ],
      child: const ShopxyCustomerApp(),
    ),
  );

  authProvider.init();
}

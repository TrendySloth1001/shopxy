import 'package:flutter/material.dart';
import 'package:shopxy/features/users/presentation/pages/users_page.dart';
import 'package:shopxy/shared/theme/app_theme.dart';

class ShopxyApp extends StatelessWidget {
  const ShopxyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'shopxy',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: const UsersPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

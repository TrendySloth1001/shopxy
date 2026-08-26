import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:shopxy/core/icons/app_icon.dart';
import 'package:shopxy/core/icons/app_icons.dart';

void main() {
  testWidgets('AppIcon does not inflate inside an oversized tight slot',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 48,
              height: 48,
              child: AppIcon(AppIcons.searchRounded, size: 20),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(HugeIcon)), const Size(20, 20));
  });

  testWidgets('AppIcon honours the requested size under loose constraints',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: AppIcon(AppIcons.refresh, size: 24)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(HugeIcon)), const Size(24, 24));
  });
}

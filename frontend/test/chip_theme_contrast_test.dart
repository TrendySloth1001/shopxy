import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/shared/theme/app_theme.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

Color _resolvedLabelColor(WidgetTester tester, String label) {
  final richText = tester.firstWidget<RichText>(
    find.descendant(of: find.text(label), matching: find.byType(RichText)),
  );
  return (richText.text as TextSpan).style!.color!;
}

void main() {
  testWidgets('unselected ChoiceChip label uses dark ink (readable)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChoiceChip(label: Text('Expired'), selected: false),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_resolvedLabelColor(tester, 'Expired'), AppPalette.light.ink);
  });

  testWidgets('selected ChoiceChip label uses onInverse (readable on fill)', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const Scaffold(
          body: ChoiceChip(label: Text('Damaged'), selected: true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_resolvedLabelColor(tester, 'Damaged'), AppPalette.light.onInverse);
  });
}

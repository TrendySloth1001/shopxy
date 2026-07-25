// Proves the app's ChipTheme keeps ChoiceChip labels readable in BOTH states —
// the "invisible light-on-light unselected chip" bug reported on the stock
// adjustment screen. We render real ChoiceChips under AppTheme.light and read
// the resolved DefaultTextStyle the chip wraps its label in.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/shared/theme/app_theme.dart';
import 'package:shopxy/shared/theme/app_palette.dart';

Color _resolvedLabelColor(WidgetTester tester, String label) {
  // Text bakes the effective DefaultTextStyle into the RichText span, so the
  // span's colour is exactly what the user sees rendered.
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

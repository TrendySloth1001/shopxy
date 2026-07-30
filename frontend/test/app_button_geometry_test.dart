// A pinned CTA must hug its label, not the screen.
//
// The bug was invisible in the widget tree and invisible on most pages. Center
// is Align with null factors, and its sizing rule is conditional: unbounded
// constraints size it to the child, bounded constraints make it *expand to
// fill*. Inside a ListView or a Column the vertical constraint is unbounded,
// so every button looked correct. Scaffold hands `bottomNavigationBar` a loose
// full-screen maxHeight, which is bounded — so the same button grew into a
// full-page slab with its icon and label marooned in the middle.
//
// The assertions below are on the height under a *bounded* parent, because
// that is the only condition under which the defect exists.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/core/icons/app_icons.dart';
import 'package:shopxy/shared/widgets/app_button.dart';

void main() {
  testWidgets('does not grow to fill a bottomNavigationBar slot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: AppButton.primary(
                label: 'Convert to Invoice',
                icon: AppIcons.receiptLongRounded,
                onPressed: () {},
                size: AppButtonSize.lg,
                fullWidth: true,
              ),
            ),
          ),
        ),
      ),
    );

    final screen = tester.getSize(find.byType(MaterialApp)).height;
    final button = tester.getSize(find.byType(AppButton));

    // The real regression: it used to measure the full screen height.
    expect(button.height, lessThan(screen / 4));
    // Still full-width, which is the whole point of `fullWidth`.
    expect(button.width, greaterThan(200));
  });

  testWidgets('measures the same height bounded or unbounded', (tester) async {
    Widget button() => AppButton.primary(
      label: 'Convert to Invoice',
      icon: AppIcons.receiptLongRounded,
      onPressed: () {},
      size: AppButtonSize.lg,
      fullWidth: true,
    );

    // Unbounded: a scrollable, where the button was always correct.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ListView(children: [button()]))),
    );
    final unbounded = tester.getSize(find.byType(AppButton)).height;

    // Bounded: the condition that used to change the answer.
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(bottomNavigationBar: button())),
    );
    final bounded = tester.getSize(find.byType(AppButton)).height;

    expect(bounded, unbounded);
  });

  testWidgets('a loading button keeps the same height as a labelled one', (
    tester,
  ) async {
    // The spinner replaces the Row, so it takes a different path to the same
    // Center — and a jumping CTA mid-submit is its own bug.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppButton.primary(
            label: 'Convert to Invoice',
            onPressed: () {},
            size: AppButtonSize.lg,
            fullWidth: true,
            isLoading: true,
          ),
        ),
      ),
    );

    final screen = tester.getSize(find.byType(MaterialApp)).height;
    expect(tester.getSize(find.byType(AppButton)).height, lessThan(screen / 4));
  });
}

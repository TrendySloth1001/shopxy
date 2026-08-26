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

    expect(button.height, lessThan(screen / 4));
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

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: ListView(children: [button()]))),
    );
    final unbounded = tester.getSize(find.byType(AppButton)).height;

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(bottomNavigationBar: button())),
    );
    final bounded = tester.getSize(find.byType(AppButton)).height;

    expect(bounded, unbounded);
  });

  testWidgets('a loading button keeps the same height as a labelled one', (
    tester,
  ) async {
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

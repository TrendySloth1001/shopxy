import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shopxy/features/profile/presentation/pages/profile_page.dart'
    show ProfileAvatar;

void main() {
  Widget harness(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  testWidgets('measures exactly its size — the ring adds no layout', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const ProfileAvatar(name: 'Nikhil Kumawat', size: 40)),
    );

    expect(tester.getSize(find.byType(ProfileAvatar)), const Size(40, 40));
  });

  testWidgets('the ring is painted in front, never declared as a border', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(const ProfileAvatar(name: 'Nikhil Kumawat', size: 40)),
    );

    final box = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(ProfileAvatar),
            matching: find.byType(Container),
          )
          .first,
    );

    expect(
      (box.decoration as BoxDecoration?)?.border,
      isNull,
      reason: 'a background border silently pads the child',
    );
    expect(
      (box.foregroundDecoration as BoxDecoration?)?.border,
      isNotNull,
      reason: 'the hairline should still be drawn',
    );
  });

  testWidgets('a failed image falls back to the monogram', (tester) async {
    await tester.pumpWidget(
      harness(
        const ProfileAvatar(
          name: 'Nikhil Kumawat',
          imageUrl: '/images/gone.webp',
          size: 40,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('N'), findsOneWidget);
  });

  testWidgets('no url renders the monogram directly', (tester) async {
    await tester.pumpWidget(harness(const ProfileAvatar(name: 'asha@x.test')));

    expect(find.text('A'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('an empty name still renders a glyph, never a blank disc', (
    tester,
  ) async {
    await tester.pumpWidget(harness(const ProfileAvatar(name: '   ')));

    expect(find.text('?'), findsOneWidget);
  });
}

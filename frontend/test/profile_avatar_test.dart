// Geometry + fallback for the shared circular avatar.
//
// Both bugs this pins were silent. A border declared in a BoxDecoration is
// reported as *padding*, so the content box shrank by the stroke on every edge
// while the child was still asked for the full diameter — the picture spilled
// past its box and got clipped, giving flat-bottomed discs. And a failed fetch
// suppressed the monogram, leaving an empty coloured circle that looked exactly
// like a user with no picture.

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

    // This is the whole bug: a border here is reported as padding, so the
    // content box shrinks by the stroke on every edge and the picture inside
    // gets clipped to fit. The ring has to live in foregroundDecoration.
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
    // The harness answers every image request with a 400.
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

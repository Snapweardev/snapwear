import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapwear_rider/royal_design.dart';

void main() {
  testWidgets('Role remains readable on a narrow screen with enlarged text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.5)),
          child: Scaffold(body: RoyalWordmark(role: 'Rider')),
        ),
      ),
    );
    expect(find.text('SNAPWEAR · Rider'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Brand without role renders correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: RoyalWordmark())),
    );
    expect(find.text('SNAPWEAR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

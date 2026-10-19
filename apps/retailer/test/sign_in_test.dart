import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapwear_retailer/main.dart';

void main() {
  testWidgets('Invalid credentials are rejected before contacting Firebase', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SignInPage()));
    await tester.enterText(find.byType(TextFormField).at(0), 'invalid-email');
    await tester.enterText(find.byType(TextFormField).at(1), '123');
    await tester.ensureVisible(find.text('SIGN IN'));
    await tester.tap(find.text('SIGN IN'));
    await tester.pump();
    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Use at least 6 characters'), findsOneWidget);
    expect(find.text('Please wait…'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

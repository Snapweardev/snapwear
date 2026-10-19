import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapwear_rider/main.dart';

void main() {
  testWidgets('Rider sign-in accepts input and masks the password', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RiderSignIn()));
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'rider@example.test');
    await tester.enterText(fields.at(1), 'example-password');
    expect(
      tester.widget<TextField>(fields.at(0)).controller!.text,
      'rider@example.test',
    );
    expect(tester.widget<TextField>(fields.at(1)).obscureText, isTrue);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snapwear_retailer/royal_design.dart';
import 'package:snapwear_retailer/snapwear_design.dart';
void main() {
 testWidgets('Brand header fits a narrow screen and exposes role', (tester) async {
  await tester.binding.setSurfaceSize(const Size(320, 640));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(theme: snapWearTheme(), home: const Scaffold(appBar: null, body: RoyalWordmark(role: 'Boutique'))));
  expect(find.text('SNAPWEAR · Boutique'), findsOneWidget);
  expect(tester.takeException(), isNull);
 });
}

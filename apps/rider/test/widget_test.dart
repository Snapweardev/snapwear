import 'package:flutter_test/flutter_test.dart';
import 'package:snapwear_rider/main.dart';

void main() {
  testWidgets('Rider login opens', (tester) async {
    await tester.pumpWidget(const RiderApp());
    expect(find.text('Local delivery testing'), findsOneWidget);
  });
}
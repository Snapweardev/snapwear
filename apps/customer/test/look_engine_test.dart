import 'package:flutter_test/flutter_test.dart';
import 'package:snap_wear/look_engine.dart';

LookPiece piece(
  String id,
  String name,
  String store,
  double price, {
  String size = 'M',
  int stock = 2,
  String description = '',
}) => LookPiece(id, {
  'name': name,
  'category': name,
  'ownerUid': store,
  'price': price,
  'description': description,
  'variants': [
    {'size': size, 'color': 'Cream', 'stock': stock},
  ],
});
void main() {
  test(
    'Keeps base, matches size and stock, stays in same store and total budget',
    () {
      final base = piece('shirt', 'Shirt', 'a', 1000);
      final items = [
        base,
        piece('pants', 'Trousers', 'a', 1200),
        piece('belt', 'Belt', 'a', 300, size: 'One size'),
        piece('cheap', 'Jeans', 'b', 100),
        piece('sold', 'Shoes', 'a', 100, stock: 0),
        piece('wrong', 'Shoes', 'a', 100, size: 'L'),
      ];
      final result = buildLook(items, base, 'M', 2500, 'Office');
      expect(result.map((p) => p.id), ['shirt', 'pants', 'belt']);
      expect(result.fold<double>(0, (s, p) => s + p.price), 2500);
      expect(buildLook(items, base, 'M', 500, 'Office'), isEmpty);
      expect(buildLook(items, base, 'L', 2500, 'Office'), isEmpty);
    },
  );
  test('One piece outfits do not add another top or bottom', () {
    final base = piece('dress', 'Silk dress', 'a', 2000);
    final result = buildLook(
      [
        base,
        piece('pants', 'Jeans', 'a', 100),
        piece('shirt', 'Shirt', 'a', 100),
        piece('bag', 'Bag', 'a', 200, size: 'One size'),
      ],
      base,
      'M',
      3000,
      'Wedding',
    );
    expect(result.map((p) => p.id), ['dress', 'bag']);
  });
  test(
    'Occasion matching ranks suitable items ahead of cheaper generic stock',
    () {
      final base = piece('shirt', 'Shirt', 'a', 1000);
      final result = buildLook(
        [
          base,
          piece('jeans', 'Jeans', 'a', 300),
          piece('formal', 'Trousers', 'a', 800, description: 'formal office'),
        ],
        base,
        'M',
        2000,
        'Office',
      );
      expect(result.map((p) => p.id), ['shirt', 'formal']);
    },
  );
}

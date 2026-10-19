import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_wear/main.dart';

void main() {
  const shirt = Product(name: 'Shirt', price: 500, icon: Icons.checkroom);
  const trousers = Product(name: 'Trousers', price: 700, icon: Icons.checkroom);
  setUp(() {
    Cart.items.clear();
    Cart.count.value = 0;
  });
  tearDown(() {
    Cart.items.clear();
    Cart.count.value = 0;
  });
  test('Adding duplicate products updates quantity and count', () {
    Cart.add(shirt);
    Cart.add(shirt);
    Cart.add(trousers);
    expect(Cart.items, [shirt, shirt, trousers]);
    expect(Cart.count.value, 3);
  });
  test('Removing one duplicate preserves remaining items', () {
    Cart.add(shirt);
    Cart.add(shirt);
    Cart.add(trousers);
    Cart.removeOne(shirt);
    expect(Cart.items, [shirt, trousers]);
    expect(Cart.count.value, 2);
  });
  test('Removing all matches preserves other products', () {
    Cart.add(shirt);
    Cart.add(shirt);
    Cart.add(trousers);
    Cart.removeAll(shirt);
    expect(Cart.items, [trousers]);
    expect(Cart.count.value, 1);
  });
  test('Removing an absent product leaves the basket unchanged', () {
    Cart.add(trousers);
    Cart.removeOne(shirt);
    Cart.removeAll(shirt);
    expect(Cart.items, [trousers]);
    expect(Cart.count.value, 1);
  });
}

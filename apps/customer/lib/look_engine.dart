class LookPiece {
  final String id;
  final Map<String, dynamic> data;
  const LookPiece(this.id, this.data);
  double get price => (data['price'] as num).toDouble();
  String get store => data['ownerUid'] as String;
  String get name => data['name'] as String;
  String get slot {
    final text = '${data['category']} $name'.toLowerCase();
    if (RegExp(r'dress|jumpsuit|gown|saree|kurta set').hasMatch(text)) {
      return 'One-piece';
    }
    if (RegExp(r'trouser|pant|jean|skirt|short|legging').hasMatch(text)) {
      return 'Bottom';
    }
    if (RegExp(r'bag|belt|watch|jewel|necklace|earring|accessor|scarf|sunglass')
        .hasMatch(text)) {
      return 'Accessory';
    }
    if (RegExp(r'shoe|sandal|sneaker|heel|footwear').hasMatch(text)) {
      return 'Footwear';
    }
    return 'Top';
  }

  List<Map> variants(String size) =>
      (data['variants'] as List? ?? []).whereType<Map>().where((v) {
        final fit = '${v['size']}'.toLowerCase();
        return (v['stock'] as num? ?? 0) > 0 &&
            (size == 'Any' ||
                fit == size.toLowerCase() ||
                [
                  'one size',
                  'free size',
                  'onesize',
                  'universal',
                ].contains(fit));
      }).toList();
  bool suits(String occasion) {
    final text =
        '${data['occasion'] ?? ''} ${data['tags'] ?? ''} ${data['description'] ?? ''} $name'
            .toLowerCase();
    final words = switch (occasion) {
      'Office' => ['office', 'formal', 'work', 'blazer'],
      'College' => ['college', 'casual', 'denim', 'hoodie'],
      'Wedding' => ['wedding', 'festive', 'ethnic', 'silk'],
      _ => ['casual', 'everyday', 'tee', 'hoodie'],
    };
    return words.any(text.contains);
  }
}

List<LookPiece> buildLook(
  List<LookPiece> catalogue,
  LookPiece base,
  String size,
  double budget,
  String occasion,
) {
  if (base.variants(size).isEmpty || base.price > budget) return [];
  final result = [base];
  final slots = base.slot == 'One-piece'
      ? ['Accessory', 'Footwear']
      : ['Top', 'Bottom', 'Accessory', 'Footwear'];
  final candidates =
      catalogue
          .where(
            (p) =>
                p.store == base.store &&
                p.id != base.id &&
                p.variants(size).isNotEmpty,
          )
          .toList()
        ..sort((a, b) {
          final rank = (b.suits(occasion) ? 1 : 0).compareTo(
            a.suits(occasion) ? 1 : 0,
          );
          return rank != 0 ? rank : a.price.compareTo(b.price);
        });
  for (final slot in slots) {
    if (result.any((p) => p.slot == slot)) continue;
    final remaining =
        budget - result.fold<double>(0, (sum, p) => sum + p.price);
    final available = candidates.where(
      (p) => p.slot == slot && p.price <= remaining,
    );
    if (available.isNotEmpty) result.add(available.first);
  }
  return result;
}

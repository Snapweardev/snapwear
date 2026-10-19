/// Merchandise revenue excludes delivery fees. Unknown legacy prices stay unknown.
int? merchandisePaise(Map<String, dynamic> order) {
  if (order['subtotalPaise'] is num) {
    return (order['subtotalPaise'] as num).round();
  }
  final lines = (order['items'] as List? ?? []).whereType<Map>().toList();
  if (lines.isEmpty || lines.any((i) => i['subtotalPaise'] is! num)) {
    return null;
  }
  return lines.fold<int>(0, (n, i) => n + (i['subtotalPaise'] as num).round());
}

/// Cash collected is the gross COD amount, not the retailer's payout.
int collectedCodPaise(Map<String, dynamic> order) {
  if (order['status'] != 'delivered' ||
      order['paymentMethod'] != 'cod' ||
      order['paymentStatus'] != 'collected') {
    return 0;
  }
  return ((order['collectedCashPaise'] ?? order['totalPaise']) as num? ?? 0)
      .round();
}

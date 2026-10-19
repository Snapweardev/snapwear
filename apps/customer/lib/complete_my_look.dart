import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'main.dart'
    show
        RetailerProductPage,
        RetailerBasketItem,
        retailerBasket,
        RetailerBasketPage;
import 'royal_design.dart';
import 'look_engine.dart';

class CompleteMyLookPage extends StatefulWidget {
  final String? initialProductId;
  const CompleteMyLookPage({super.key, this.initialProductId});
  @override
  State<CompleteMyLookPage> createState() => _CompleteMyLookState();
}

class _CompleteMyLookState extends State<CompleteMyLookPage> {
  String occasion = 'Casual', size = 'Any';
  String? baseId;
  double budget = 5000;
  List<String> pickedIds = [];
  late final stream = FirebaseFirestore.instance
      .collection('publishedProducts')
      .snapshots();
  @override
  void initState() {
    super.initState();
    baseId = widget.initialProductId;
    loadPreferences();
  }

  Future<void> loadPreferences() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance
          .doc('users/${user.uid}')
          .get();
      final prefs = doc.data()?['stylePreferences'] as Map?;
      if (!mounted || prefs == null || pickedIds.isNotEmpty) return;
      setState(() {
        size = prefs['size'] as String? ?? 'Any';
        occasion =
            [
              'Office',
              'College',
              'Wedding',
              'Casual',
            ].contains(prefs['occasion'])
            ? prefs['occasion']
            : 'Casual';
        budget = ((prefs['budget'] as num?)?.toDouble() ?? 5000).clamp(
          500,
          20000,
        );
      });
    } catch (_) {
      /* Optional defaults should never block outfit building. */
    }
  }

  void generate(List<LookPiece> products) {
    final base = products.where((p) => p.id == baseId).firstOrNull;
    setState(
      () => pickedIds = base == null
          ? []
          : buildLook(
              products,
              base,
              size,
              budget,
              occasion,
            ).map((p) => p.id).toList(),
    );
  }

  Future<void> swap(
    List<LookPiece> products,
    List<LookPiece> selected,
    LookPiece current,
  ) async {
    final otherTotal = selected
        .where((p) => p.id != current.id)
        .fold<double>(0, (s, p) => s + p.price);
    final options = products
        .where(
          (p) =>
              p.store == current.store &&
              p.slot == current.slot &&
              p.id != current.id &&
              !pickedIds.contains(p.id) &&
              p.variants(size).isNotEmpty &&
              p.price + otherTotal <= budget,
        )
        .toList();
    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: 380,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Swap this piece',
                style: TextStyle(fontFamily: 'SnapSerif', fontSize: 28),
              ),
              const Text(
                'Same boutique, same clothing type, within your total budget.',
              ),
              if (options.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Text(
                    'No alternative in your size and budget yet. Your look stays unchanged.',
                  ),
                ),
              ...options.map(
                (p) => ListTile(
                  title: Text(p.name),
                  subtitle: Text('₹${p.price.toStringAsFixed(0)}'),
                  onTap: () => Navigator.pop(context, p.id),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice != null && mounted) {
      setState(() {
        pickedIds = pickedIds
            .map((id) => id == current.id ? choice : id)
            .toList();
        if (baseId == current.id) baseId = choice;
      });
    }
  }

  void addLook(List<LookPiece> selected, List<LookPiece> products) {
    final current = [...retailerBasket.value];
    final store = selected.first.store;
    for (final item in current) {
      final product = products.where((p) => p.id == item.id).firstOrNull;
      if (product == null || product.store != store) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your basket contains another boutique. Review it before adding this look.',
            ),
          ),
        );
        return;
      }
    }
    for (final p in selected) {
      final v = p.variants(size).first;
      final index = current.indexWhere(
        (i) => i.id == p.id && i.size == v['size'] && i.color == v['color'],
      );
      final qty = index < 0 ? 1 : current[index].quantity + 1;
      if (qty > (v['stock'] as num)) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'This quantity exceeds current stock. Review your basket.',
            ),
          ),
        );
        return;
      }
      final item = RetailerBasketItem(
        p.id,
        v['size'] as String,
        v['color'] as String,
        qty,
      );
      if (index < 0) {
        current.add(item);
      } else {
        current[index] = item;
      }
    }
    retailerBasket.value = current;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RetailerBasketPage()),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Complete My Look')),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Could not load your local edit. Please reopen this page.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final products = snapshot.data!.docs
            .map((d) => LookPiece(d.id, d.data()))
            .toList();
        final available = products
            .where((p) => p.variants(size).isNotEmpty)
            .toList();
        final sizes = {
          'Any',
          ...products.expand(
            (p) => (p.data['variants'] as List).whereType<Map>().map(
              (v) => v['size'] as String,
            ),
          ),
        }.toList();
        final selected = pickedIds
            .map((id) => products.where((p) => p.id == id).firstOrNull)
            .whereType<LookPiece>()
            .toList();
        final total = selected.fold<double>(0, (s, p) => s + p.price);
        final valid =
            selected.isNotEmpty &&
            selected.length == pickedIds.length &&
            total <= budget &&
            selected.every((p) => p.variants(size).isNotEmpty);
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 740),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text(
                  'One piece. Your whole look.',
                  style: TextStyle(
                    fontFamily: 'SnapSerif',
                    fontSize: 36,
                    color: royalInk,
                  ),
                ),
                const Text(
                  'Start with a favourite. We find complementary clothing types from the same boutique, using available sizes and your total item budget.',
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  children: ['Office', 'College', 'Wedding', 'Casual']
                      .map(
                        (v) => ChoiceChip(
                          label: Text(v),
                          selected: occasion == v,
                          onSelected: (_) => setState(() {
                            occasion = v;
                            pickedIds = [];
                          }),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey('fit-$size'),
                  initialValue: sizes.contains(size) ? size : 'Any',
                  decoration: const InputDecoration(labelText: 'Clothing size'),
                  items: sizes
                      .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                      .toList(),
                  onChanged: (v) => setState(() {
                    size = v!;
                    pickedIds = [];
                  }),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total item budget · ₹${budget.toInt()}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Slider(
                  value: budget,
                  min: 500,
                  max: 20000,
                  divisions: 39,
                  label: '₹${budget.toInt()}',
                  onChanged: (v) => setState(() {
                    budget = v;
                    pickedIds = [];
                  }),
                ),
                DropdownButtonFormField<String>(
                  key: ValueKey('$size|$baseId'),
                  initialValue: available.any((p) => p.id == baseId)
                      ? baseId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Start with an item',
                  ),
                  items: available
                      .map(
                        (p) => DropdownMenuItem(
                          value: p.id,
                          child: Text(
                            '${p.name} · ₹${p.price.toInt()}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    baseId = v;
                    pickedIds = [];
                  }),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: available.any((p) => p.id == baseId)
                      ? () => generate(products)
                      : null,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Build my look'),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Occasion uses retailer descriptions and tags where available. Suggestions are a starting point; review colours and styling yourself. Delivery is added at checkout.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF756D60)),
                ),
                if (available.isEmpty)
                  const Text(
                    'No items in this size are currently available. Try another size.',
                  ),
                if (baseId != null &&
                    available.any((p) => p.id == baseId && p.price > budget))
                  const Text(
                    'Your starting item exceeds this budget. Increase it or choose another piece.',
                  ),
                if (selected.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Your look · ₹${total.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 30,
                    ),
                  ),
                  Text('${selected.first.data['storeName']} · one boutique'),
                  if (selected.length == 1)
                    const Text(
                      'Only your starting piece matches right now. This boutique needs more complementary stock to complete the outfit.',
                    ),
                  ...selected.map((p) {
                    final variants = p.variants(size);
                    return Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: SizedBox(
                                width: 60,
                                height: 76,
                                child: Image.network(
                                  p.data['photoUrl'] as String,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) =>
                                      const Icon(Icons.checkroom),
                                ),
                              ),
                              title: Text(p.name),
                              subtitle: Text(
                                '${p.slot} · ₹${p.price.toInt()}\n${variants.isEmpty ? 'No longer available in this size' : '${variants.first['size']} / ${variants.first['color']}'}',
                              ),
                            ),
                            Wrap(
                              spacing: 10,
                              children: [
                                TextButton(
                                  onPressed: () => swap(products, selected, p),
                                  child: const Text('Swap piece'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          RetailerProductPage(id: p.id),
                                    ),
                                  ),
                                  child: const Text('View details'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  FilledButton(
                    onPressed: valid ? () => addLook(selected, products) : null,
                    child: Text(
                      'Add ${selected.length} pieces · ₹${total.toStringAsFixed(0)}',
                    ),
                  ),
                  if (!valid)
                    const Text(
                      'Availability changed. Build your look again before adding it.',
                    ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

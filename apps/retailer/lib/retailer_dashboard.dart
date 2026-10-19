import 'royal_design.dart';
import 'retailer_connections.dart';
import 'retailer_dates.dart';
import 'retailer_metrics.dart';

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'snapwear_design.dart';

typedef OrderTileBuilder = Widget Function(
  String id,
  Map<String, dynamic> data,
);

class RetailerWorkspace extends StatefulWidget {
  final String uid;
  final Map<String, dynamic> store;
  final VoidCallback addProduct, signOut;
  final void Function(String id, Map<String, dynamic> data) editProduct,
      duplicateProduct,
      editStock;
  final OrderTileBuilder orderTile;
  const RetailerWorkspace({
    super.key,
    required this.uid,
    required this.store,
    required this.addProduct,
    required this.editProduct,
    required this.duplicateProduct,
    required this.editStock,
    required this.signOut,
    required this.orderTile,
  });
  @override
  State<RetailerWorkspace> createState() => _RetailerWorkspaceState();
}

class _RetailerWorkspaceState extends State<RetailerWorkspace> {
  int tab = 0;
  String datePreset = 'Last 7 days';
  DateTimeRange? customRange;
  String orderFilter = 'Active', productFilter = 'All', query = '';
  late final Stream<QuerySnapshot<Map<String, dynamic>>> orders,
      products,
      publications;
  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    orders = db
        .collection('clothingOrders')
        .where('retailerUid', isEqualTo: widget.uid)
        .snapshots();
    products = db
        .collection('retailerApplications')
        .doc(widget.uid)
        .collection('products')
        .snapshots();
    publications = db
        .collection('publishedProducts')
        .where('ownerUid', isEqualTo: widget.uid)
        .snapshots();
  }

  Future<DateTimeRange?> pickCustomDates(DateTime today) {
    DateTime from = customRange?.start ?? DateTime(today.year, today.month, 1);
    DateTime to = customRange?.end ?? today;
    String? error;
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return showDialog<DateTimeRange>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialog) {
          Widget dateRow(
            String label,
            DateTime value,
            void Function(DateTime) change,
          ) {
            void update({int? year, int? month, int? day}) {
              final y = year ?? value.year, m = month ?? value.month;
              final lastDay = DateTime(y, m + 1, 0).day;
              change(DateTime(y, m, math.min(day ?? value.day, lastDay)));
              setDialog(() => error = null);
            }

            Widget select(
              String title,
              int current,
              List<DropdownMenuItem<int>> items,
              void Function(int) changed,
            ) => DropdownButtonFormField<int>(
              key: ValueKey(
                '$label-$title-$current-${value.year}-${value.month}',
              ),
              initialValue: current,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: title,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              items: items,
              onChanged: (v) {
                if (v != null) {
                  changed(v);
                }
              },
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: select(
                        'Year',
                        value.year,
                        List.generate(
                          today.year - 1999,
                          (i) => DropdownMenuItem(
                            value: today.year - i,
                            child: Text('${today.year - i}'),
                          ),
                        ),
                        (y) => update(year: y),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: select(
                        'Month',
                        value.month,
                        List.generate(
                          12,
                          (i) => DropdownMenuItem(
                            value: i + 1,
                            child: Text(months[i]),
                          ),
                        ),
                        (m) => update(month: m),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                select(
                  'Day',
                  value.day,
                  List.generate(
                    DateTime(value.year, value.month + 1, 0).day,
                    (i) =>
                        DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
                  ),
                  (d) => update(day: d),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Custom date range'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select the year, month and day for both dates. The To date is included in your report.',
                    ),
                    const SizedBox(height: 24),
                    dateRow('From', from, (v) => from = v),
                    const SizedBox(height: 24),
                    dateRow('To', to, (v) => to = v),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(
                          error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  if (to.isBefore(from)) {
                    setDialog(
                      () => error = 'To date must be on or after From date.',
                    );
                    return;
                  }
                  if (from.isAfter(today) || to.isAfter(today)) {
                    setDialog(() => error = 'Choose dates up to today.');
                    return;
                  }
                  Navigator.pop(
                    dialogContext,
                    DateTimeRange(start: from, end: to),
                  );
                },
                child: const Text('Apply range'),
              ),
            ],
          );
        },
      ),
    );
  }

  DateTime? date(dynamic value) => value is Timestamp ? value.toDate() : null;
  bool inRange(DateTime? value, DateTime start, DateTime end) =>
      value != null && !value.isBefore(start) && value.isBefore(end);
  String money(num paise) => '₹${(paise / 100).toStringAsFixed(2)}';
  String shortDate(DateTime d) => '${d.day}/${d.month}/${d.year}';
  Widget heading(String title, [String? subtitle]) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w800,
            color: snapForest,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(color: Color(0xFF786B60), height: 1.4),
          ),
        ],
      ],
    ),
  );
  Widget chips(
    List<String> labels,
    String selected,
    void Function(String) choose,
  ) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: labels
          .map(
            (label) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(label),
                selected: selected == label,
                onSelected: (_) => choose(label),
              ),
            ),
          )
          .toList(),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const RoyalWordmark(role: 'Boutique'),
      actions: [
        IconButton(
          tooltip: 'Sign out',
          onPressed: widget.signOut,
          icon: const Icon(Icons.logout),
        ),
      ],
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: tab,
      onDestinationSelected: (i) => setState(() => tab = i),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Analytics',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: 'Catalogue',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          label: 'Store',
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1100),
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: orders,
          builder: (context, os) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: products,
              builder: (context, ps) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: publications,
                  builder: (context, live) {
                    if (os.hasError || ps.hasError || live.hasError) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Cannot load your store dashboard. Check the emulator connection and retailer access.',
                          ),
                        ),
                      );
                    }
                    if (!os.hasData || !ps.hasData || !live.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final orderDocs = [...os.data!.docs]
                      ..sort(
                        (a, b) =>
                            (date(b.data()['createdAt']) ?? DateTime(1970))
                                .compareTo(
                                  date(a.data()['createdAt']) ?? DateTime(1970),
                                ),
                      );
                    final productDocs = ps.data!.docs;
                    final liveIds = live.data!.docs
                        .map((d) => d.data()['productId'])
                        .toSet();
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                      children: [
                        if (tab == 0)
                          ...overview(orderDocs, productDocs, liveIds),
                        if (tab == 1) ...orderList(orderDocs),
                        if (tab == 2) ...productList(productDocs, liveIds),
                        if (tab == 3) ...storeDetails(),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    ),
  );
  List<Widget> overview(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> inventory,
    Set<dynamic> liveIds,
  ) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final window = reportDateWindow(
      datePreset,
      now,
      records: docs
          .expand(
            (d) => [date(d.data()['createdAt']), date(d.data()['deliveredAt'])],
          )
          .whereType<DateTime>()
          .toList(),
      customStart: customRange?.start,
      customEnd: customRange?.end,
    );
    final start = window.start, end = window.end;
    final days = math.max(1, end.difference(start).inDays);
    final bins = math.min(7, days);
    final lastDay = end.subtract(const Duration(days: 1));
    final placed = docs
        .where((d) => inRange(date(d.data()['createdAt']), start, end))
        .toList();
    final delivered = docs
        .where(
          (d) =>
              d.data()['status'] == 'delivered' &&
              inRange(date(d.data()['deliveredAt']), start, end),
        )
        .toList();
    final sales = delivered.fold<int>(
      0,
      (n, d) => n + (merchandisePaise(d.data()) ?? 0),
    );
    final collected = delivered.fold<int>(
      0,
      (n, d) => n + collectedCodPaise(d.data()),
    );
    final active = docs
        .where(
          (d) => [
            'placed',
            'accepted',
            'preparing',
            'ready',
            'assigned',
            'picked_up',
          ].contains(d.data()['status']),
        )
        .toList();
    final newCount = active.where((d) => d.data()['status'] == 'placed').length;
    final cancel = placed
        .where((d) => ['cancelled', 'rejected'].contains(d.data()['status']))
        .toList();
    final unknown = docs
        .where(
          (d) =>
              d.data()['status'] == 'delivered' &&
              (date(d.data()['deliveredAt']) == null ||
                  merchandisePaise(d.data()) == null),
        )
        .length;
    final orderBars = List<double>.filled(bins, 0),
        salesBars = List<double>.filled(bins, 0);
    int bucket(DateTime d) =>
        ((DateTime(d.year, d.month, d.day).difference(start).inDays * bins) ~/
                days)
            .clamp(0, bins - 1);
    for (final d in placed) {
      orderBars[bucket(date(d.data()['createdAt'])!)]++;
    }
    for (final d in delivered) {
      salesBars[bucket(date(d.data()['deliveredAt'])!)] +=
          (merchandisePaise(d.data()) ?? 0) / 100;
    }
    final reasons = <String, int>{}, best = <String, int>{};
    for (final d in cancel) {
      final r = d.data()['cancellationReason'] as String? ?? 'Not recorded';
      reasons[r] = (reasons[r] ?? 0) + 1;
    }
    for (final d in delivered) {
      for (final i in (d.data()['items'] as List? ?? []).whereType<Map>()) {
        final name = i['name'] as String? ?? 'Product';
        best[name] = (best[name] ?? 0) + (i['quantity'] as num? ?? 0).toInt();
      }
    }
    final ranked = best.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final alerts = <Map<String, dynamic>>[];
    for (final p in inventory) {
      for (final v in (p.data()['variants'] as List? ?? []).whereType<Map>()) {
        final stock = (v['stock'] as num? ?? 0).toInt();
        if (stock <= 3) {
          alerts.add({
            'doc': p,
            'size': v['size'],
            'color': v['color'],
            'stock': stock,
          });
        }
      }
    }
    final report =
        '${widget.store['storeName']}\n${shortDate(start)} – ${shortDate(lastDay)}\nPlaced orders: ${placed.length}\nDelivered orders: ${delivered.length}\nDelivered merchandise sales: ${money(sales)}\nCollected COD including delivery: ${money(collected)}\nCancelled/rejected from placed orders: ${cancel.length}\nActive orders (all dates): ${active.length}\nSales are not profit or payouts. Local test data.';
    return [
      SnapWearHero(
        eyebrow: 'YOUR STORE DESK',
        title: widget.store['storeName'] as String? ?? 'Your store',
        subtitle:
            '$newCount new orders need attention · ${active.length} active orders',
        icon: Icons.storefront_outlined,
      ),
      const SizedBox(height: 20),
      chips(
        [
          'Today',
          'Last 7 days',
          'This month',
          'Last month',
          'Last 90 days',
          'All time',
          'Custom',
        ],
        datePreset,
        (v) async {
          if (v == 'Custom') {
            final picked = await pickCustomDates(today);
            if (picked == null || !mounted) {
              return;
            }
            setState(() {
              customRange = picked;
              datePreset = v;
            });
          } else {
            setState(() => datePreset = v);
          }
        },
      ),
      const SizedBox(height: 12),
      Text('${shortDate(start)} – ${shortDate(lastDay)} · local device dates'),
      const SizedBox(height: 16),
      LayoutBuilder(
        builder: (context, bounds) {
          final width = (bounds.maxWidth - 12) / 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              MetricTile(
                width: width,
                label: 'Delivered sales',
                value: money(sales),
                note: 'Merchandise only',
                icon: Icons.trending_up,
              ),
              MetricTile(
                width: width,
                label: 'Orders placed',
                value: '${placed.length}',
                note: '${delivered.length} delivered in period',
                icon: Icons.receipt_long_outlined,
              ),
              MetricTile(
                width: width,
                label: 'Collected COD',
                value: money(collected),
                note: 'Includes delivery · not a payout',
                icon: Icons.payments_outlined,
              ),
              MetricTile(
                width: width,
                label: 'Cancelled / rejected',
                value: '${cancel.length}',
                note: placed.isEmpty
                    ? 'No placed orders'
                    : '${(cancel.length / placed.length * 100).toStringAsFixed(1)}% of placed orders',
                icon: Icons.cancel_outlined,
              ),
            ],
          );
        },
      ),
      heading(
        'Store performance',
        'Sales use delivery dates; order counts use placement dates.',
      ),
      RetailerBarChart(
        values: salesBars,
        title: 'Delivered merchandise sales (₹)',
        labels: List.generate(
          bins,
          (i) => shortDate(start.add(Duration(days: (i * days / bins).ceil()))),
        ),
      ),
      RetailerBarChart(
        values: orderBars,
        title: 'Orders placed',
        labels: List.generate(
          bins,
          (i) => shortDate(start.add(Duration(days: (i * days / bins).ceil()))),
        ),
      ),
      if (unknown > 0)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '$unknown older delivered orders have incomplete date or price records. Missing values are excluded from the relevant sales totals.',
          ),
        ),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton.icon(
            onPressed: () => setState(() {
              tab = 1;
              orderFilter = 'New';
            }),
            icon: const Icon(Icons.receipt_long),
            label: Text('New orders ($newCount)'),
          ),
          OutlinedButton.icon(
            onPressed: widget.addProduct,
            icon: const Icon(Icons.add),
            label: const Text('Add product'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: report));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Store report copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_outlined),
            label: const Text('Copy report'),
          ),
        ],
      ),
      heading(
        'Stock needs attention',
        '${alerts.length} size/colour combinations have 3 units or fewer. All products, including drafts.',
      ),
      if (alerts.isEmpty) const Text('No low-stock alerts.'),
      ...alerts.take(6).map((a) {
        final p = a['doc'] as QueryDocumentSnapshot<Map<String, dynamic>>;
        return Card(
          child: ListTile(
            leading: Icon(
              a['stock'] == 0
                  ? Icons.error_outline
                  : Icons.inventory_2_outlined,
              color: snapTerracotta,
            ),
            title: Text(p.data()['name'] as String? ?? 'Product'),
            subtitle: Text('${a['size']} / ${a['color']} · ${a['stock']} left'),
            trailing: const Icon(Icons.edit_outlined),
            onTap: () => widget.editStock(p.id, p.data()),
          ),
        );
      }),
      if (alerts.length > 6)
        TextButton(
          onPressed: () => setState(() {
            tab = 2;
            productFilter = 'Low stock';
          }),
          child: const Text('View all stock alerts'),
        ),
      heading(
        'Best sellers',
        'Units from orders delivered in the selected period.',
      ),
      if (ranked.isEmpty)
        const Text('Your best sellers will appear after deliveries.'),
      ...ranked
          .take(5)
          .map(
            (e) => Card(
              child: ListTile(
                leading: const Icon(Icons.checkroom_outlined),
                title: Text(e.key),
                trailing: Text('${e.value} units'),
              ),
            ),
          ),
      heading(
        'Cancellation reasons',
        'Cancelled or rejected orders placed in the selected period.',
      ),
      if (reasons.isEmpty) const Text('No cancellations in this period.'),
      ...reasons.entries.map(
        (e) => Card(
          child: ListTile(title: Text(e.key), trailing: Text('${e.value}')),
        ),
      ),
      const SizedBox(height: 20),
      const Text(
        'Local test analytics. Sales exclude delivery fees. COD collection does not mean a retailer payout. Costs, commissions, refunds and settlements are not connected.',
        style: TextStyle(fontSize: 12, color: Color(0xFF786B60)),
      ),
    ];
  }

  List<Widget> orderList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    const groups = {
      'New': ['placed'],
      'Preparing': ['accepted', 'preparing'],
      'Ready': ['ready', 'assigned'],
      'On the way': ['picked_up'],
      'Completed': ['delivered'],
      'Cancelled': ['cancelled', 'rejected'],
    };
    final selected = docs
        .where(
          (d) =>
              orderFilter == 'All' ||
              (orderFilter == 'Active'
                      ? [
                          'placed',
                          'accepted',
                          'preparing',
                          'ready',
                          'assigned',
                          'picked_up',
                        ]
                      : groups[orderFilter] ?? [])
                  .contains(d.data()['status']),
        )
        .toList();
    return [
      heading(
        'Fulfilment',
        'Accept → prepare → mark ready. Riders are assigned automatically.',
      ),
      chips(
        [
          'Active',
          'New',
          'Preparing',
          'Ready',
          'On the way',
          'Completed',
          'Cancelled',
          'All',
        ],
        orderFilter,
        (s) => setState(() => orderFilter = s),
      ),
      const SizedBox(height: 16),
      Text('${selected.length} orders'),
      const SizedBox(height: 12),
      if (selected.isEmpty)
        const Padding(
          padding: EdgeInsets.all(24),
          child: Text('No orders in this view.'),
        ),
      ...selected.map(
        (d) => KeyedSubtree(
          key: ValueKey(d.id),
          child: widget.orderTile(d.id, d.data()),
        ),
      ),
    ];
  }

  List<Widget> productList(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    Set<dynamic> liveIds,
  ) {
    final filtered = docs.where((d) {
      final variants = (d.data()['variants'] as List? ?? [])
          .whereType<Map>()
          .toList();
      final low = variants.any((v) => (v['stock'] as num? ?? 0) <= 3);
      final match =
          productFilter == 'All' ||
          productFilter == 'Live' && liveIds.contains(d.id) ||
          productFilter == 'Drafts' && !liveIds.contains(d.id) ||
          productFilter == 'Low stock' && low;
      return match &&
          '${d.data()['name']} ${d.data()['brand']}'.toLowerCase().contains(
            query.toLowerCase(),
          );
    }).toList();
    return [
      heading(
        'Catalogue',
        '${liveIds.length} live listings · ${docs.length} product drafts',
      ),
      FilledButton.icon(
        onPressed: widget.addProduct,
        icon: const Icon(Icons.add),
        label: const Text('Add product'),
      ),
      const SizedBox(height: 20),
      TextField(
        onChanged: (v) => setState(() => query = v),
        decoration: const InputDecoration(
          hintText: 'Search products or brands',
          prefixIcon: Icon(Icons.search),
        ),
      ),
      const SizedBox(height: 12),
      chips(
        ['All', 'Live', 'Drafts', 'Low stock'],
        productFilter,
        (v) => setState(() => productFilter = v),
      ),
      const SizedBox(height: 20),
      if (filtered.isEmpty)
        const Text(
          'No matching products. Add a product or change your filters.',
        ),
      ...filtered.map((d) {
        final data = d.data(),
            variants = (d.data()['variants'] as List? ?? []).whereType<Map>();
        final stock = variants.fold<int>(
          0,
          (n, v) => n + (v['stock'] as num? ?? 0).toInt(),
        );
        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: const CircleAvatar(
              backgroundColor: snapPeach,
              child: Icon(Icons.checkroom_outlined, color: snapForest),
            ),
            title: Text(
              data['name'] as String? ?? 'Product',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(
              '${data['brand']} · ₹${data['price']}\n$stock units across ${variants.length} variants · ${liveIds.contains(d.id) ? 'Live listing + private draft' : 'Private draft only'}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: 'Product actions',
              onSelected: (v) {
                if (v == 'copy') {
                  widget.duplicateProduct(d.id, data);
                }
                if (v == 'stock') {
                  widget.editStock(d.id, data);
                }
                if (v == 'edit') {
                  widget.editProduct(d.id, data);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit product')),
                PopupMenuItem(value: 'stock', child: Text('Quick stock edit')),
                PopupMenuItem(value: 'copy', child: Text('Duplicate product')),
              ],
            ),
            onTap: () => widget.editProduct(d.id, data),
          ),
        );
      }),
    ];
  }

  List<Widget> storeDetails() => [
    FilledButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RetailerConnectionsPage(uid: widget.uid),
        ),
      ),
      icon: const Icon(Icons.link),
      label: const Text('Website integration & GST verification'),
    ),
    const SizedBox(height: 16),
    heading('Store profile', 'Your registered details and approval status.'),
    Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.store['storeName'] as String? ?? 'Store',
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Text('Approval: ${widget.store['status']}'),
            const Divider(height: 32),
            Text(
              'Contact: ${widget.store['contactName']}\nPhone: ${widget.store['phone']}',
            ),
            const SizedBox(height: 16),
            Text(
              '${widget.store['address']}\n${widget.store['city']} · ${widget.store['pin']}',
            ),
            const SizedBox(height: 16),
            Text('Brands: ${widget.store['brands'] ?? 'Not specified'}'),
          ],
        ),
      ),
    ),
    const Text(
      'Profile editing and delivery-area changes need a separate authorised setup. Product and stock changes are available in Products.',
    ),
  ];
}

class MetricTile extends StatelessWidget {
  final double width;
  final String label, value, note;
  final IconData icon;
  const MetricTile({
    super.key,
    required this.width,
    required this.label,
    required this.value,
    required this.note,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: snapTerracotta),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                  color: snapForest,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              note,
              style: const TextStyle(fontSize: 11, color: Color(0xFF786B60)),
            ),
          ],
        ),
      ),
    ),
  );
}

class RetailerBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String title;
  const RetailerBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.title,
  });
  @override
  Widget build(BuildContext context) {
    final maxValue = math.max(
      1.0,
      values.fold<double>(0, (n, v) => math.max(n, v)),
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            SizedBox(
              height: 170,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(
                  values.length,
                  (i) => Expanded(
                    child: Tooltip(
                      message:
                          'From ${labels[i]}: ${values[i].toStringAsFixed(2)}',
                      child: Semantics(
                        label:
                            'From ${labels[i]}, ${values[i].toStringAsFixed(2)}',
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              FittedBox(
                                child: Text(
                                  values[i] == values[i].roundToDouble()
                                      ? '${values[i].toInt()}'
                                      : values[i].toStringAsFixed(1),
                                  style: const TextStyle(fontSize: 10),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                height: values[i] == 0
                                    ? 2
                                    : 120 * values[i] / maxValue,
                                decoration: BoxDecoration(
                                  color: values[i] == 0
                                      ? snapPeach
                                      : snapTerracotta,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                labels[i],
                                style: const TextStyle(fontSize: 9),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (values.every((v) => v == 0))
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'No activity in this period.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

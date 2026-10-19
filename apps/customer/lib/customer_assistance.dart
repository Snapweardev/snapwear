import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import 'connected_features.dart';

class AddressSuggestions extends StatelessWidget {
  final TextEditingController pin, address, city;
  final bool enabled;
  const AddressSuggestions({
    super.key,
    required this.pin,
    required this.address,
    required this.city,
    this.enabled = true,
  });
  @override
  Widget build(BuildContext context) {
    if (!RegExp(r'^[1-9][0-9]{5}$').hasMatch(pin.text)) {
      return const SizedBox.shrink();
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .doc('addressDirectory/${pin.text}')
          .snapshots(),
      builder: (context, s) {
        if (s.hasError) {
          return const Text(
            'Address suggestions unavailable. You can enter your address manually.',
          );
        }
        if (!s.hasData) return const LinearProgressIndicator();
        final d = s.data!.data();
        if (d == null) {
          return const Text(
            'No verified street directory for this PIN yet. Enter the area and street manually.',
          );
        }
        final areas = (d['areas'] as List? ?? []).whereType<String>().toList();
        final streets = (d['streets'] as List? ?? [])
            .whereType<String>()
            .where(
              (v) =>
                  address.text.trim().isNotEmpty &&
                  v.toLowerCase().contains(address.text.trim().toLowerCase()),
            )
            .take(8)
            .toList();
        void choose(String v) {
          address.text = v;
          if (d['city'] is String) city.text = d['city'];
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Areas for your PIN',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: areas
                    .map(
                      (a) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ActionChip(
                          label: Text(a),
                          onPressed: enabled ? () => choose(a) : null,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (streets.isNotEmpty) ...[
              const Text('Matching streets'),
              ...streets.map(
                (v) => ListTile(
                  dense: true,
                  title: Text(v),
                  onTap: enabled ? () => choose(v) : null,
                ),
              ),
            ],
            const Text(
              'Add your house or flat number after selecting a street.',
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class NearbyStoresPage extends StatefulWidget {
  final String initialQuery;
  const NearbyStoresPage({super.key, this.initialQuery = ''});
  @override
  State<NearbyStoresPage> createState() => _NearbyStoresPageState();
}

class _NearbyStoresPageState extends State<NearbyStoresPage> {
  late final TextEditingController itemQuery;
  @override
  void initState() {
    super.initState();
    itemQuery = TextEditingController(text: widget.initialQuery);
  }

  Position? position;
  String? error;
  bool busy = false;
  double radius = 10;
  @override
  void dispose() {
    itemQuery.dispose();
    super.dispose();
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Enable location services to find nearby stores.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location access declined. Allow location access to find stores near you.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (mounted) setState(() => position = p);
    } catch (e) {
      if (mounted) setState(() => error = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  double distance(Map<String, dynamic> d) =>
      Geolocator.distanceBetween(
        position!.latitude,
        position!.longitude,
        (d['latitude'] as num).toDouble(),
        (d['longitude'] as num).toDouble(),
      ) /
      1000;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Nearby clothing stores')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          widget.initialQuery.isEmpty
              ? 'Find stores near you'
              : 'Find your item nearby',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Location is used when you tap the button. Only participating stores with reviewed shop coordinates appear here.',
        ),
        const SizedBox(height: 16),
        TextField(
          controller: itemQuery,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Search item, brand or store',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: busy ? null : locate,
          icon: const Icon(Icons.my_location),
          label: Text(busy ? 'Locating…' : 'Use my location'),
        ),
        if (error != null) Text(error!),
        if (position != null) ...[
          Text('Within ${radius.toInt()} km'),
          Slider(
            value: radius,
            min: 1,
            max: 50,
            divisions: 49,
            onChanged: (v) => setState(() => radius = v),
          ),
        ],
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('publishedProducts')
              .snapshots(),
          builder: (context, productsSnapshot) {
            if (productsSnapshot.hasError) {
              return const Text(
                'Could not check item availability. Please try again.',
              );
            }
            if (!productsSnapshot.hasData) {
              return const LinearProgressIndicator();
            }
            final query = itemQuery.text.trim().toLowerCase();
            final matching = <String, List<Map<String, dynamic>>>{};
            for (final product in productsSnapshot.data!.docs) {
              final data = product.data();
              final text =
                  '${data['name']} ${data['category']} ${data['brand']} ${data['storeName']}'
                      .toLowerCase();
              final inStock = (data['variants'] as List? ?? [])
                  .whereType<Map>()
                  .any((v) => (v['stock'] as num? ?? 0) > 0);
              if (inStock && query.split(RegExp(r'\s+')).every(text.contains)) {
                matching
                    .putIfAbsent(data['ownerUid'] as String, () => [])
                    .add(data);
              }
            }
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('storeDirectory')
                  .snapshots(),
              builder: (context, s) {
                if (s.hasError) {
                  return const Text('Could not load stores. Try again later.');
                }
                if (!s.hasData) return const LinearProgressIndicator();
                var docs = s.data!.docs.where((doc) {
                  final d = doc.data();
                  if (!matching.containsKey(doc.id)) return false;
                  if (position != null) {
                    return d['latitude'] is num &&
                        d['longitude'] is num &&
                        distance(d) <= radius;
                  }
                  return false;
                }).toList();
                if (position != null) {
                  docs.sort(
                    (a, b) => distance(a.data()).compareTo(distance(b.data())),
                  );
                }
                if (position == null) {
                  return const Text(
                    'Tap Use my location to find stores with this item nearby.',
                  );
                }
                if (docs.isEmpty) {
                  return const Text(
                    'No nearby participating store currently has a matching item in stock. Try another item or expand your radius.',
                  );
                }
                return Column(
                  children: docs.map((doc) {
                    final d = doc.data();
                    return Card(
                      child: ListTile(
                        leading: const Icon(Icons.storefront),
                        title: Text(d['storeName'] as String),
                        subtitle: Text(
                          '${d['address']}\n${d['city']} · ${d['pin']}${position == null ? ' · Same PIN' : ' · ${distance(d).toStringAsFixed(1)} km'}\nIn stock: ${matching[doc.id]!.map((p) => p['name']).take(3).join(', ')}',
                        ),
                        onTap: () => Navigator.pop(context, doc.id),
                      ),
                    );
                  }).toList(),
                );
              },
            );
          },
        ),
      ],
    ),
  );
}

class CustomerReceiptButton extends StatelessWidget {
  final String orderId;
  final Map<String, dynamic> order;
  const CustomerReceiptButton({
    super.key,
    required this.orderId,
    required this.order,
  });
  @override
  Widget build(BuildContext context) => TextButton.icon(
    icon: const Icon(Icons.receipt_long_outlined),
    label: const Text('Receipt & email bill'),
    onPressed: () async {
      String money(dynamic v) =>
          '₹${((v as num? ?? 0) / 100).toStringAsFixed(2)}';
      final text =
          'SnapWear order receipt\nOrder: $orderId\nStore: ${order['storeName']}\nStatus: ${order['status']}\nPayment: ${order['paymentStatus']}\n${(order['items'] as List).map((i) => "${i['name']} · ${i['size']} / ${i['color']} × ${i['quantity']} · ${money(i['subtotalPaise'])}").join('\n')}\nItems: ${money(order['subtotalPaise'])}\nDelivery: ${money(order['deliveryFeePaise'])}\nTotal: ${money(order['totalPaise'])}\nOrder receipt; retailer issues the GST tax invoice.';
      await showDialog<void>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Your receipt'),
          content: SingleChildScrollView(child: SelectableText(text)),
          actions: [
            TextButton(
              onPressed: () => Clipboard.setData(ClipboardData(text: text)),
              child: const Text('Copy receipt'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final r = await featureCall('emailCustomerReceipt', {
                    'orderId': orderId,
                  });
                  if (c.mounted) {
                    ScaffoldMessenger.of(c).showSnackBar(
                      SnackBar(
                        content: Text(
                          r['status'] == 'sent'
                              ? 'Receipt email sent.'
                              : r['status'] == 'awaiting_verified_email'
                              ? 'Verify your account email before placing your next order. Copy this receipt for now.'
                              : 'Email sender setup pending. Copy your receipt for now.',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (c.mounted) {
                    ScaffoldMessenger.of(c)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
                }
              },
              child: const Text('Email receipt'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    },
  );
}

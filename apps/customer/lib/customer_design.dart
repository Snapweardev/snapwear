import 'package:flutter/material.dart';

import 'snapwear_design.dart';

class CustomerSection extends StatelessWidget {
  final String label, title;
  final String? subtitle;
  const CustomerSection({
    super.key,
    required this.label,
    required this.title,
    this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: snapTerracotta,
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            color: snapForest,
            fontSize: 30,
            height: 1.15,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            style: const TextStyle(color: Color(0xFF665B50), height: 1.5),
          ),
        ],
      ],
    ),
  );
}

class CustomerNotice extends StatelessWidget {
  final String text;
  final IconData icon;
  const CustomerNotice(this.text, {super.key, this.icon = Icons.info_outline});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: 12),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: snapPeach,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: snapTerracotta, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Color(0xFF573B2D), height: 1.5),
          ),
        ),
      ],
    ),
  );
}

class CustomerProductCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onOpen;
  const CustomerProductCard({
    super.key,
    required this.data,
    required this.onOpen,
  });
  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ColoredBox(
            color: const Color(0xFFF6EDE3),
            child: Image.network(
              data['photoUrl'] as String,
              webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
              height: 260,
              fit: BoxFit.contain,
              errorBuilder: (_, error, stack) => const SizedBox(
                height: 180,
                child: Center(
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 64,
                    color: snapForest,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${data['brand']} · ${data['category']}',
                  style: const TextStyle(
                    color: snapTerracotta,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  data['name'] as String,
                  style: const TextStyle(
                    fontSize: 24,
                    color: snapForest,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(data['storeName'] as String),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '₹${(data['price'] as num).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: onOpen,
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Choose fit'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class CustomerOrderProgress extends StatelessWidget {
  final String status;
  const CustomerOrderProgress({super.key, required this.status});
  @override
  Widget build(BuildContext context) {
    final terminal = ['cancelled', 'rejected'].contains(status);
    const steps = [
      'placed',
      'accepted',
      'preparing',
      'ready',
      'assigned',
      'picked_up',
      'delivered',
    ];
    const labels = [
      'Placed',
      'Accepted',
      'Preparing',
      'Ready',
      'Rider assigned',
      'On the way',
      'Delivered',
    ];
    final current = steps.indexOf(status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Chip(
            avatar: Icon(
              terminal ? Icons.cancel_outlined : Icons.local_shipping_outlined,
              size: 18,
              color: terminal ? snapTerracotta : snapForest,
            ),
            label: Text(
              terminal
                  ? (status == 'cancelled' ? 'Cancelled' : 'Rejected')
                  : (current >= 0 ? labels[current] : status),
            ),
          ),
          if (!terminal) ...[
            const SizedBox(height: 10),
            Row(
              children: List.generate(
                steps.length,
                (i) => Expanded(
                  child: Container(
                    height: 5,
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: i <= current ? snapForest : snapPeach,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Store preparation → pickup → delivery',
              style: TextStyle(fontSize: 12, color: Color(0xFF665B50)),
            ),
          ],
        ],
      ),
    );
  }
}

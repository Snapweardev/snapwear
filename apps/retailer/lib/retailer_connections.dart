import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'connected_features.dart';

class RetailerConnectionsPage extends StatefulWidget {
  final String uid;
  const RetailerConnectionsPage({super.key, required this.uid});
  @override
  State<RetailerConnectionsPage> createState() =>
      _RetailerConnectionsPageState();
}

class _RetailerConnectionsPageState extends State<RetailerConnectionsPage> {
  final website = TextEditingController(),
      feed = TextEditingController(),
      gstin = TextEditingController(),
      legal = TextEditingController(),
      lat = TextEditingController(),
      lng = TextEditingController();
  String platform = 'Custom',
      message = '',
      certificate = '',
      fileName = 'No file selected';
  bool busy = false;
  @override
  void dispose() {
    for (final c in [website, feed, gstin, legal, lat, lng]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> action(Future<String> Function() task) async {
    setState(() {
      busy = true;
      message = '';
    });
    try {
      final result = await task();
      if (mounted) setState(() => message = result);
    } catch (e) {
      if (mounted) setState(() => message = '$e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> chooseCertificate() async {
    final image = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > 400000) {
      throw StateError('Choose a JPEG or PNG below 400 KB.');
    }
    if (mounted) {
      setState(() {
        certificate = base64Encode(bytes);
        fileName = image.name;
      });
    }
  }

  Widget input(TextEditingController c, String label, {int lines = 1}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextField(
          controller: c,
          enabled: !busy,
          maxLines: lines,
          decoration: InputDecoration(labelText: label),
        ),
      );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Integrations & verification')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const Text(
              'Website integration',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Connect your website catalogue and route COD orders to SnapWear fulfilment. Your website developer installs the signed webhook adapter. A website link alone cannot connect private orders.',
            ),
            const SizedBox(height: 20),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('websiteConnections/${widget.uid}')
                  .snapshots(),
              builder: (context, s) {
                if (s.hasError) return const Text('Unable to load connection.');
                final d = s.data?.data();
                return Text(
                  d == null
                      ? 'No website connected'
                      : 'Website: ${d['website'] ?? 'Not saved'}\nConnection: ${d['status'] ?? 'setup_required'}\nLast catalogue import: ${d['lastImportCount'] ?? 0} products',
                );
              },
            ),
            const SizedBox(height: 16),
            input(website, 'Website URL (https://)'),
            DropdownButtonFormField<String>(
              initialValue: platform,
              decoration: const InputDecoration(labelText: 'Website platform'),
              items: [
                'Custom',
                'Shopify',
                'WooCommerce',
              ].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
              onChanged: busy ? null : (v) => setState(() => platform = v!),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      await featureCall('saveWebsiteConnection', {
                        'website': website.text.trim(),
                        'platform': platform,
                      });
                      return 'Website saved. Install the adapter to enable order routing.';
                    }),
              child: const Text('Save website'),
            ),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () async {
                      final yes = await showDialog<bool>(
                        context: context,
                        builder: (c) => AlertDialog(
                          title: const Text('Generate a signing key?'),
                          content: const Text(
                            'This replaces any existing key. Update your website adapter with the new key. Do not put it in browser code.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(c, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(c, true),
                              child: const Text('Generate'),
                            ),
                          ],
                        ),
                      );
                      if (yes != true) return;
                      await action(() async {
                        final r = await featureCall('enableWebsiteWebhook', {});
                        if (!context.mounted) return 'Key generated';
                        await showDialog<void>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('Website adapter signing key'),
                            content: SelectableText(
                              'Retailer UID: ${r['retailerUid']}\nSigning key: ${r['secret']}\nKeep this key on your website server only. It is shown once.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c),
                                child: const Text('Done'),
                              ),
                            ],
                          ),
                        );
                        return 'Signing key generated. Complete the adapter setup before sending orders.';
                      });
                    },
              child: const Text('Generate / rotate webhook key'),
            ),
            const Divider(height: 40),
            const Text(
              'Import catalogue',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Paste your website’s authorised JSON product export. Photos and descriptions become private drafts. Stock starts at zero; review and allocate stock before publishing. Repeated source IDs are rejected to protect existing stock.',
            ),
            const SizedBox(height: 16),
            input(feed, 'Product JSON array', lines: 7),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => feed.text = jsonEncode([
                      {
                        'sourceId': 'website-sku-1',
                        'name': 'Linen shirt',
                        'brand': 'Your brand',
                        'category': 'Shirts',
                        'description': 'Breathable linen shirt',
                        'price': 999,
                        'photoUrl':
                            'https://your-store.example/photos/shirt.jpg',
                        'variants': [
                          {'size': 'M', 'color': 'White', 'stock': 0},
                        ],
                      },
                    ]),
              child: const Text('Insert import template'),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      final products = jsonDecode(feed.text);
                      final r = await featureCall('importWebsiteCatalogue', {
                        'products': products,
                      });
                      return '${r['imported']} private drafts imported. Review photos, prices and inventory in Catalogue.\nWebsite order mapping:\n${jsonEncode(r['mapping'])}';
                    }),
              child: const Text('Import as drafts'),
            ),
            const Divider(height: 40),
            const Text(
              'GST verification',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Submit your GST registration certificate privately for owner review. Submission does not mean verification.',
            ),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('retailerVerifications/${widget.uid}')
                  .snapshots(),
              builder: (c, s) {
                if (s.hasError) {
                  return const Text('Unable to load verification.');
                }
                final d = s.data?.data();
                return Text(
                  'Verification: ${d?['status'] ?? 'Not submitted'}\n${d?['reason'] ?? ''}',
                );
              },
            ),
            const SizedBox(height: 16),
            input(gstin, 'GSTIN'),
            input(legal, 'Registered legal name'),
            input(lat, 'Shop latitude (optional)'),
            input(lng, 'Shop longitude (optional)'),
            const Text(
              'Shop coordinates are published only after owner review, so customers can find your store nearby.',
            ),
            OutlinedButton.icon(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      await chooseCertificate();
                      return fileName;
                    }),
              icon: const Icon(Icons.upload_file),
              label: Text(fileName),
            ),
            FilledButton(
              onPressed: busy
                  ? null
                  : () => action(() async {
                      await featureCall('submitRetailerVerification', {
                        'gstin': gstin.text.trim().toUpperCase(),
                        'legalName': legal.text.trim(),
                        'certificateBase64': certificate,
                        'latitude': double.tryParse(lat.text),
                        'longitude': double.tryParse(lng.text),
                      });
                      return 'Certificate submitted for review.';
                    }),
              child: const Text('Submit verification'),
            ),
            if (busy) const LinearProgressIndicator(),
            if (message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: SelectableText(message),
              ),
            const SizedBox(height: 24),
            const Text(
              'Certificate format: JPEG or PNG, up to 400 KB. PDF support will require document storage.',
            ),
          ],
        ),
      ),
    ),
  );
}

class GstReviewCard extends StatelessWidget {
  final String uid;
  const GstReviewCard({super.key, required this.uid});
  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
    stream: FirebaseFirestore.instance
        .doc('retailerVerifications/$uid')
        .snapshots(),
    builder: (context, s) {
      if (s.hasError) return const Text('Cannot load private GST submission.');
      final d = s.data?.data();
      if (d == null) return const Text('GST: No certificate submitted.');
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GST: ${d['gstin']} · ${d['status']}\nLegal name: ${d['legalName']}\nReview: ${d['reason'] ?? 'Awaiting review'}',
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('Private GST certificate'),
                content: SizedBox(
                  width: 600,
                  child: Image.memory(
                    base64Decode(d['certificateBase64'] as String),
                    errorBuilder: (_, e, st) =>
                        const Text('Certificate could not be displayed'),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(c),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
            child: const Text('View certificate'),
          ),
          if (d['status'] == 'pending')
            Wrap(
              spacing: 12,
              children: ['approved', 'rejected']
                  .map(
                    (status) => OutlinedButton(
                      onPressed: () async {
                        String reason = '';
                        final yes = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: Text('$status GST submission'),
                            content: TextField(
                              maxLength: 300,
                              onChanged: (v) => reason = v,
                              decoration: const InputDecoration(
                                labelText: 'Review reason',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text('Save review'),
                              ),
                            ],
                          ),
                        );
                        if (yes != true) return;
                        try {
                          await featureCall('reviewRetailerVerification', {
                            'retailerUid': uid,
                            'status': status,
                            'reason': reason.trim(),
                          });
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context)
                                .showSnackBar(SnackBar(content: Text('$e')));
                          }
                        }
                      },
                      child: Text(
                        status == 'approved'
                            ? 'Verify GST'
                            : 'Reject certificate',
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      );
    },
  );
}

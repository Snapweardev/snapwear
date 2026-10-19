import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'connected_features.dart';

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

import 'dart:convert';

import 'package:flutter/material.dart';

import 'connected_features.dart';

class AddressDirectoryPage extends StatefulWidget {
  const AddressDirectoryPage({super.key});
  @override
  State<AddressDirectoryPage> createState() => _AddressDirectoryPageState();
}

class _AddressDirectoryPageState extends State<AddressDirectoryPage> {
  final data = TextEditingController();
  bool busy = false;
  String message = '';
  @override
  void dispose() {
    data.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Address directory')),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          'Add verified pilot-city addresses',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const Text(
          'Upload verified PIN, locality and street records. Suggestions appear in customer checkout. Empty or unknown PINs retain manual entry.',
        ),
        const SizedBox(height: 20),
        TextField(
          controller: data,
          maxLines: 12,
          decoration: const InputDecoration(
            labelText: 'Directory JSON',
            hintText:
                '{"pin":"600041","city":"Chennai","areas":[],"streets":[]}',
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await featureCall(
                      'saveAddressDirectory',
                      Map<String, dynamic>.from(jsonDecode(data.text) as Map),
                    );
                    if (mounted) {
                      setState(
                        () => message = 'Verified address directory saved.',
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => message = '$e');
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          child: const Text('Save verified addresses'),
        ),
        Text(message),
      ],
    ),
  );
}

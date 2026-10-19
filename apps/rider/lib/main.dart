import 'royal_design.dart';

import 'package:flutter/foundation.dart';

import 'local_auth_reset.dart'
    if (dart.library.js_interop) 'local_auth_reset_web.dart';
import 'connected_features.dart';
import 'snapwear_design.dart';
import 'startup_splash.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')) {
    await resetLocalAuthMarker();
  }
  if (!const bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Start with --dart-define=SNAPWEAR_LOCAL_TEST=true. This rider build is for local testing only.',
            ),
          ),
        ),
      ),
    );
    return;
  }
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'demo-local-key',
      appId: '1:123456789:web:riderlocaltest',
      messagingSenderId: '123456789',
      projectId: 'demo-snapwear',
    ),
  );
  const host = String.fromEnvironment(
    'SNAPWEAR_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );
  await FirebaseAuth.instance.useAuthEmulator(host, 9099);
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  }
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: false,
  );
  FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
  runApp(const RiderApp());
}

class RiderApp extends StatelessWidget {
  const RiderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'SnapWear Rider TEST',
    theme: snapWearTheme(),
    builder: (context, child) => RoyalFrame(child: child!),
    home: SnapWearOpening(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) => snapshot.data == null
            ? const RiderSignIn()
            : RiderJobs(user: snapshot.data!),
      ),
    ),
  );
}

class RiderSignIn extends StatefulWidget {
  const RiderSignIn({super.key});
  @override
  State<RiderSignIn> createState() => _RiderSignInState();
}

class _RiderSignInState extends State<RiderSignIn> {
  final email = TextEditingController(), password = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> login() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Sign-in failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const RoyalWordmark(role: 'Rider')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 550),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.all(24),
          children: [
            const SnapWearHero(
              eyebrow: 'SNAPWEAR RIDER',
              title: 'Great style, delivered.',
              subtitle: 'Sign in and go online to receive ready orders automatically.',
              icon: Icons.two_wheeler,
            ),
            const SizedBox(height: 24),
            const Text(
              'No live deliveries or money collection. Use your local test account.',
            ),
            const SizedBox(height: 20),
            TextField(
              controller: email,
              enabled: !busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Rider email'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: password,
              enabled: !busy,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            FilledButton(
              onPressed: busy ? null : login,
              child: Text(busy ? 'Signing in…' : 'SIGN IN'),
            ),
            const GoogleLoginButton(),
          ],
        ),
      ),
    ),
  );
}

class RiderJobs extends StatelessWidget {
  final User user;
  const RiderJobs({super.key, required this.user});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const RoyalWordmark(role: 'Rider'),
      actions: [
        TextButton(
          onPressed: () => FirebaseAuth.instance.signOut(),
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('riderProfiles')
          .doc(user.uid)
          .snapshots(),
      builder: (context, profile) {
        if (profile.hasError) {
          return const Center(
            child: Text('Cannot load rider access. Check local rules.'),
          );
        }
        if (!profile.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (profile.data!.data()?['status'] != 'approved') {
          return const Center(
            child: Text('Approved rider access is required.'),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('clothingOrders')
              .where('riderUid', isEqualTo: user.uid)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text('Cannot load assigned deliveries.'),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final docs = [...snapshot.data!.docs]
              ..sort(
                (a, b) =>
                    ((b.data()['updatedAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0)
                        .compareTo(
                          (a.data()['updatedAt'] as Timestamp?)
                                  ?.millisecondsSinceEpoch ??
                              0,
                        ),
              );
            if (docs.isEmpty) {
              return ListView(
                children: [
                  const SnapWearHero(
                    eyebrow: 'YOUR DELIVERY DESK',
                    title: 'Ready for the next stop.',
                    subtitle: 'Go online to receive orders. Your active delivery stays assigned when you go offline.',
                    icon: Icons.two_wheeler,
                  ),
                  const SizedBox(height: 20),
                  RiderAvailability(
                    online: profile.data!.data()?['online'] == true,
                  ),
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No assigned deliveries yet. Go online to receive ready orders automatically.',
                    ),
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const SnapWearHero(
                  eyebrow: 'YOUR DELIVERY DESK',
                  title: 'Ready for the next stop.',
                  subtitle: 'Go online to receive orders. Your active delivery stays assigned when you go offline.',
                  icon: Icons.two_wheeler,
                ),
                const SizedBox(height: 20),
                RiderAvailability(
                  online: profile.data!.data()?['online'] == true,
                ),
                ...docs.map(
                  (doc) => RiderJobCard(
                    key: ValueKey(doc.id),
                    id: doc.id,
                    data: doc.data(),
                  ),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class RiderJobCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  const RiderJobCard({super.key, required this.id, required this.data});
  @override
  State<RiderJobCard> createState() => _RiderJobCardState();
}

class _RiderJobCardState extends State<RiderJobCard> {
  bool busy = false;
  String? error;
  Future<void> advance(String next) async {
    final total = widget.data['totalPaise'] as num;
    var deliveryCode = "";
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          next == 'picked_up' ? 'Confirm pickup?' : 'Confirm delivery and COD?',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              next == 'picked_up'
                  ? 'Confirm you collected the correct items from the store. This is a local test.'
                  : 'Ask the customer for their delivery code after handing over the clothes. Confirm simulated COD collection of ₹${(total / 100).toStringAsFixed(2)}. No money is transferred.',
            ),
            if (next == 'delivered')
              TextField(
                onChanged: (value) => deliveryCode = value.trim(),
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  labelText: 'Customer delivery code',
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      const host = String.fromEnvironment(
        'SNAPWEAR_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      final response = await http
          .post(
            Uri.parse(
              'http://$host:5001/demo-snapwear/asia-south1/advanceClothingDelivery',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'data': {
                'orderId': widget.id,
                'nextStatus': next,
                if (next == 'delivered') 'confirmedCashPaise': total,
                if (next == 'delivered') 'deliveryCode': deliveryCode,
              },
            }),
          )
          .timeout(const Duration(seconds: 30));
      final decoded = jsonDecode(response.body) as Map;
      if (decoded['error'] != null) {
        throw Exception((decoded['error'] as Map)['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data,
        pickup = d['pickup'] as Map?,
        address = d['address'] as Map;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['storeName'] as String,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),
            Text('Status: ${d['status']}'),
            SelectableText('Order: ${widget.id}'),
            const SizedBox(height: 16),
            const Text('PICKUP', style: TextStyle(fontWeight: FontWeight.bold)),
            if (pickup != null)
              Text(
                '${pickup['address']}\n${pickup['city']} · ${pickup['pin']}\nStore phone: ${pickup['phone']}',
              ),
            const SizedBox(height: 16),
            const Text(
              'DELIVERY',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              '${address['name']} · ${address['phone']}\n${address['address']}\n${address['city']} · ${address['pin']}',
            ),
            ...((d['items'] as List).cast<Map>().map(
              (i) => Text(
                '${i['name']} · ${i['size']} / ${i['color']} × ${i['quantity']}',
              ),
            )),
            Text(
              'COD: ₹${((d['totalPaise'] as num) / 100).toStringAsFixed(2)} · ${d['paymentStatus']}',
            ),
            const SizedBox(height: 16),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (d['status'] == 'assigned')
              FilledButton(
                onPressed: busy ? null : () => advance('picked_up'),
                child: Text(busy ? 'Updating…' : 'CONFIRM PICKUP'),
              ),
            if (d['status'] == 'picked_up')
              FilledButton(
                onPressed: busy ? null : () => advance('delivered'),
                child: Text(busy ? 'Updating…' : 'CONFIRM DELIVERY + TEST COD'),
              ),
            const Text(
              'Local test only. Delivery code is verified locally. Live GPS, SMS and payout settlement are not connected.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class RiderAvailability extends StatefulWidget {
  final bool online;
  const RiderAvailability({super.key, required this.online});
  @override
  State<RiderAvailability> createState() => _RiderAvailabilityState();
}

class _RiderAvailabilityState extends State<RiderAvailability> {
  bool busy = false;
  String? error;
  Future<void> change(bool online) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      const host = String.fromEnvironment(
        'SNAPWEAR_EMULATOR_HOST',
        defaultValue: '127.0.0.1',
      );
      final token = await FirebaseAuth.instance.currentUser!.getIdToken();
      final response = await http
          .post(
            Uri.parse(
              'http://$host:5001/demo-snapwear/asia-south1/setRiderAvailability',
            ),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'data': {'online': online},
            }),
          )
          .timeout(const Duration(seconds: 30));
      final body = jsonDecode(response.body) as Map;
      if (body['error'] != null) {
        throw Exception((body['error'] as Map)['message']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '$e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      SwitchListTile(
        title: Text(
          widget.online
              ? 'Online — automatic assignments enabled'
              : 'Offline — no new assignments',
        ),
        subtitle: const Text(
          'One active delivery at a time. Matching uses the service PIN, not GPS. Going offline keeps your current delivery.',
        ),
        value: widget.online,
        onChanged: busy ? null : change,
      ),
      if (error != null)
        Text(error!, style: const TextStyle(color: Colors.red)),
    ],
  );
}

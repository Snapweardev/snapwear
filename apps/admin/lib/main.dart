import 'royal_design.dart';

import 'package:flutter/foundation.dart';

import 'local_auth_reset.dart'
    if (dart.library.js_interop) 'local_auth_reset_web.dart';
import 'address_admin.dart';
import 'retailer_connections.dart';
import 'connected_features.dart';
import 'snapwear_design.dart';
import 'startup_splash.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (const bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')) {
    await resetLocalAuthMarker();
  }
  try {
    await Firebase.initializeApp(
      options: const bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')
          ? const FirebaseOptions(
              apiKey: 'demo-local-key',
              appId: '1:123456789:web:localtest',
              messagingSenderId: '123456789',
              projectId: 'demo-snapwear',
            )
          : DefaultFirebaseOptions.currentPlatform,
    );
    const localTest = bool.fromEnvironment('SNAPWEAR_LOCAL_TEST');
    if (localTest) {
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
    }

    runApp(const RetailerApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Text(
              'Firebase could not start. Check configuration and restart.',
            ),
          ),
        ),
      ),
    );
  }
}

class RetailerApp extends StatelessWidget {
  const RetailerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'SnapWear Admin',
    debugShowCheckedModeBanner: false,
    theme: snapWearTheme(),
    builder: (context, child) => RoyalFrame(child: child!),
    home: SnapWearOpening(
      child: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          return snapshot.data == null
              ? const SignInPage()
              : AdminPage(
                  key: ValueKey(snapshot.data!.uid),
                  user: snapshot.data!,
                );
        },
      ),
    ),
  );
}

class SignInPage extends StatefulWidget {
  const SignInPage({super.key});
  @override
  State<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends State<SignInPage> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(), password = TextEditingController();
  bool signup = false, busy = false;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.text.trim(),
        password: password.text,
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => error = e.message ?? 'Sign-in failed. Please retry.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not connect. Please retry.');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const RoyalWordmark(role: 'Owner')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              signup ? 'Bring your store online.' : 'Welcome back.',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sign in with the SnapWear owner account. Access is enforced by Firestore rules.',
            ),
            const SizedBox(height: 28),
            Form(
              key: form,
              child: Column(
                children: [
                  TextFormField(
                    controller: email,
                    enabled: !busy,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) =>
                        RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                            .hasMatch(v?.trim() ?? '')
                        ? null
                        : 'Enter a valid email',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: password,
                    enabled: !busy,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (v) => (v?.length ?? 0) >= 6
                        ? null
                        : 'Use at least 6 characters',
                  ),
                ],
              ),
            ),
            if (error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(error!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Please wait…'
                    : signup
                    ? 'CREATE ACCOUNT'
                    : 'SIGN IN',
              ),
            ),
            const GoogleLoginButton(),
          ],
        ),
      ),
    ),
  );
}

const ownerUid = 'SWDNXmzS0cX2W0NUNKSBYGrP3SY2';

class AdminPage extends StatefulWidget {
  final User user;
  const AdminPage({super.key, required this.user});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  String? busyId, error;
  late final Stream<QuerySnapshot<Map<String, dynamic>>> applications;
  @override
  void initState() {
    super.initState();
    applications = FirebaseFirestore.instance
        .collection('retailerApplications')
        .snapshots();
  }

  Future<void> logout() async {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Could not sign out. Retry.');
      }
    }
  }

  Future<void> review(
    DocumentSnapshot<Map<String, dynamic>> application,
    String status,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          status == 'approved'
              ? 'Approve this retailer?'
              : 'Reject this application?',
        ),
        content: Text(
          '${application.data()?['storeName']}\nProduct drafts remain private. This changes the store application status only.',
        ),
        actions: [
          IconButton(
            tooltip: 'Clothing orders',
            onPressed: widget.user.uid == ownerUid
                ? () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ClothingOrdersPage(admin: true),
                    ),
                  )
                : null,
            icon: const Icon(Icons.receipt_long),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (yes != true || !mounted) {
      return;
    }
    setState(() {
      busyId = application.id;
      error = null;
    });
    try {
      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
            final latest = await transaction.get(application.reference);
            if (status == 'approved') {
              final gst = await transaction.get(
                FirebaseFirestore.instance.doc(
                  'retailerVerifications/${application.id}',
                ),
              );
              if (gst.data()?['status'] != 'approved') {
                throw StateError('Verify the retailer GST certificate first.');
              }
            }
            if (latest.data()?['status'] != 'pending') {
              throw StateError('Application already reviewed');
            }
            transaction.update(application.reference, {
              'status': status,
              'reviewedAt': FieldValue.serverTimestamp(),
            });
          })
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not confirm review. Verify the GST certificate before approval, and check connection and admin rules.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busyId = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const RoyalWordmark(role: 'Owner'),
      actions: [
        IconButton(
          tooltip: 'Clothing orders',
          onPressed: widget.user.uid == ownerUid
              ? () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ClothingOrdersPage(admin: true),
                  ),
                )
              : null,
          icon: const Icon(Icons.receipt_long),
        ),
        TextButton(
          onPressed: busyId == null ? logout : null,
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: widget.user.uid != ownerUid
        ? const Center(
            child: Text(
              'Owner access only. Sign out and use the authorised owner account.',
            ),
          )
        : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: applications,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: SelectableText(
                      'Cannot read applications.\nOwner UID: ${widget.user.uid}\nError: ${snapshot.error}',
                    ),
                  ),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs;
              final pending = docs
                  .where((doc) => doc.data()['status'] == 'pending')
                  .length;
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 900),
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      const SnapWearHero(
                        eyebrow: 'SNAPWEAR OWNER',
                        title: 'Your city, at a glance.',
                        subtitle: 'Review retailer applications and monitor orders, deliveries and cancellation reasons.',
                        icon: Icons.dashboard_outlined,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const ClothingOrdersPage(admin: true),
                          ),
                        ),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: const Text('VIEW ORDERS & CANCELLATIONS'),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AddressDirectoryPage(),
                          ),
                        ),
                        icon: const Icon(Icons.map_outlined),
                        label: const Text('Pilot city address directory'),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Retailer applications',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${docs.length} applications · $pending awaiting review',
                      ),
                      const SizedBox(height: 24),
                      if (error != null)
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      if (docs.isEmpty)
                        const Text('No retailer applications yet.'),
                      ...docs.map((doc) {
                        final data = doc.data();
                        final status = data['status'] ?? 'pending';
                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['storeName'] as String? ?? 'Store',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text('Status: $status'),
                                Text(
                                  'Contact: ${data['contactName']} · ${data['phone']}',
                                ),
                                Text(
                                  '${data['address']}\n${data['city']} · ${data['pin']}',
                                ),
                                Text('Brands: ${data['brands']}'),
                                GstReviewCard(uid: doc.id),
                                if (status == 'pending')
                                  Padding(
                                    padding: const EdgeInsets.only(top: 16),
                                    child: Wrap(
                                      spacing: 12,
                                      runSpacing: 12,
                                      children: [
                                        FilledButton(
                                          onPressed: busyId == null
                                              ? () => review(doc, 'approved')
                                              : null,
                                          child: Text(
                                            busyId == doc.id
                                                ? 'Saving…'
                                                : 'Approve',
                                          ),
                                        ),
                                        OutlinedButton(
                                          onPressed: busyId == null
                                              ? () => review(doc, 'rejected')
                                              : null,
                                          child: const Text('Reject'),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            },
          ),
  );
}

Future<Map<String, dynamic>> clothingCall(
  String name,
  Map<String, dynamic> data,
) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    throw Exception('Sign in before continuing.');
  }
  final token = await user.getIdToken();
  final response = await http
      .post(
        Uri.parse(
          const bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')
              ? 'http://${const String.fromEnvironment('SNAPWEAR_EMULATOR_HOST', defaultValue: '127.0.0.1')}:5001/demo-snapwear/asia-south1/$name'
              : 'https://asia-south1-snapwear-3222a.cloudfunctions.net/$name',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 30));
  final decoded = jsonDecode(response.body) as Map<String, dynamic>;
  if (decoded['error'] != null) {
    throw Exception((decoded['error'] as Map)['message']);
  }
  return Map<String, dynamic>.from(decoded['result'] as Map);
}

class ClothingOrdersPage extends StatelessWidget {
  final bool retailer, admin;
  const ClothingOrdersPage({
    super.key,
    this.retailer = false,
    this.admin = false,
  });
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')
                ? 'TEST clothing orders'
                : 'Clothing orders',
          ),
        ),
        body: const Center(
          child: Text('Sign in to view your clothing orders.'),
        ),
      );
    }
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance.collection(
      'clothingOrders',
    );
    if (!admin) {
      query = query.where(
        retailer ? 'retailerUid' : 'customerUid',
        isEqualTo: user.uid,
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          bool.fromEnvironment('SNAPWEAR_LOCAL_TEST')
              ? 'TEST clothing orders'
              : 'Clothing orders',
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Cannot load orders. Check the latest rules and connection.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No clothing orders yet.'));
          }
          final docs = [...snapshot.data!.docs]
            ..sort(
              (a, b) =>
                  ((b.data()['createdAt'] as Timestamp?)
                              ?.millisecondsSinceEpoch ??
                          0)
                      .compareTo(
                        (a.data()['createdAt'] as Timestamp?)
                                ?.millisecondsSinceEpoch ??
                            0,
                      ),
            );
          return ListView(
            padding: const EdgeInsets.all(16),
            children: docs
                .map(
                  (doc) => ClothingOrderCard(
                    id: doc.id,
                    data: doc.data(),
                    retailer: retailer,
                    admin: admin,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }
}

class ClothingOrderCard extends StatefulWidget {
  final String id;
  final Map<String, dynamic> data;
  final bool retailer, admin;
  const ClothingOrderCard({
    super.key,
    required this.id,
    required this.data,
    required this.retailer,
    this.admin = false,
  });
  @override
  State<ClothingOrderCard> createState() => _ClothingOrderCardState();
}

class _ClothingOrderCardState extends State<ClothingOrderCard> {
  bool busy = false;
  String? error;
  Future<void> advance(String next) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await clothingCall('advanceClothingOrder', {
        'orderId': widget.id,
        'nextStatus': next,
      });
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

  Future<void> cancel(String action) async {
    final reasons = action == 'reject'
        ? [
            'Item out of stock',
            'Store cannot fulfil order',
            'Store closed',
            'Delivery address unavailable',
          ]
        : [
            'Ordered by mistake',
            'Wrong size or colour',
            'Delivery address changed',
            'Changed my mind',
          ];
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(
          action == 'reject'
              ? 'Why are you rejecting this order?'
              : 'Why are you cancelling this order?',
        ),
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Reserved stock will be restored. No payment has been collected.',
            ),
          ),
          ...reasons.map(
            (reason) => SimpleDialogOption(
              onPressed: () => Navigator.pop(context, reason),
              child: Text(reason),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep order'),
          ),
        ],
      ),
    );
    if (reason == null || !mounted) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await clothingCall('cancelClothingOrder', {
        'orderId': widget.id,
        'action': action,
        'reason': reason,
      });
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
    final d = widget.data;
    final address = d['address'] as Map;
    final next = {
      'placed': 'accepted',
      'accepted': 'preparing',
      'preparing': 'ready',
    }[d['status']];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              d['storeName'] as String,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SelectableText('Order: ${widget.id}'),
            Text('Status: ${d['status']}'),
            Text('Payment: ${d['paymentMethod']} · ${d['paymentStatus']}'),
            ...((d['items'] as List).cast<Map>().map(
              (i) => Text(
                "${i['name']} · ${i['size']} / ${i['color']} × ${i['quantity']}",
              ),
            )),
            Text(
              'Total: ₹${((d['totalPaise'] as num) / 100).toStringAsFixed(2)}',
            ),
            Text(
              '${address['name']} · ${address['phone']}\n${address['address']}\n${address['city']} · ${address['pin']}',
            ),
            Text(
              d['riderName'] == null
                  ? 'Automatic rider assignment after preparation; waiting for an available rider.'
                  : 'Rider: ${d['riderName']}',
            ),
            const Text(
              'Status updates only; live GPS tracking is not connected.',
            ),
            if (!widget.admin && ['placed', 'accepted'].contains(d['status']))
              TextButton(
                onPressed: busy
                    ? null
                    : () => cancel(widget.retailer ? 'reject' : 'cancel'),
                child: Text(widget.retailer ? 'REJECT ORDER' : 'CANCEL ORDER'),
              ),
            if (['cancelled', 'rejected'].contains(d['status']))
              Text(
                'Reason: ${d['cancellationReason'] ?? 'Not recorded for this older order'} · By: ${d['cancelledByRole'] ?? 'Unknown'}',
              ),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.red)),
            if (widget.retailer && next != null)
              FilledButton(
                onPressed: busy ? null : () => advance(next),
                child: Text(
                  busy
                      ? 'Updating…'
                      : {
                          'accepted': 'ACCEPT ORDER',
                          'preparing': 'START PREPARING',
                          'ready': 'MARK READY FOR PICKUP',
                        }[next]!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

import 'royal_design.dart';

import 'package:flutter/foundation.dart';

import 'connected_features.dart';
import 'local_auth_reset.dart'
    if (dart.library.js_interop) 'local_auth_reset_web.dart';

import 'package:image_picker/image_picker.dart';

import 'retailer_dashboard.dart';
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
    title: 'SnapWear Retailer',
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
              : RetailerLanding(
                  key: ValueKey(snapshot.data!.uid),
                  user: snapshot.data!,
                );
        },
      ),
    ),
  );
}

class RetailerLanding extends StatelessWidget {
  final User user;
  const RetailerLanding({super.key, required this.user});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('retailerApplications')
            .doc(user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Scaffold(
              body: Center(
                child: Text(
                  'Could not load your store. Check connection and retailer access.',
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          final store = snapshot.data!.data();
          if (store == null) return StorePage(user: user);
          return RetailerWorkspace(
            uid: user.uid,
            store: store,
            addProduct: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ProductForm(uid: user.uid)),
            ),
            editProduct: (id, data) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProductForm(uid: user.uid, productId: id, initial: data),
              ),
            ),
            duplicateProduct: (id, data) => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    ProductForm(uid: user.uid, initial: data, duplicate: true),
              ),
            ),
            editStock: (id, data) => quickStock(context, user.uid, id, data),
            signOut: () async {
              try {
                await FirebaseAuth.instance.signOut();
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not sign out. Please retry.'),
                    ),
                  );
                }
              }
            },
            orderTile: (id, data) => ClothingOrderCard(
              key: ValueKey(id),
              id: id,
              data: data,
              retailer: true,
            ),
          );
        },
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
      if (signup) {
        await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(
          () => error =
              '${e.code}: ${e.message ?? 'Sign-in failed. Please retry.'}',
        );
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
    appBar: AppBar(title: const RoyalWordmark(role: 'Boutique')),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SnapWearHero(
              eyebrow: 'FOR LOCAL BOUTIQUES',
              title: signup
                  ? 'Bring your boutique online.'
                  : 'Your boutique, beautifully.',
              subtitle: 'Manage your collection, fulfil orders and follow your revenue.',
              icon: Icons.storefront_outlined,
            ),
            const SizedBox(height: 12),
            const Text(
              'Register your store for review. Product publishing becomes available after platform approval.',
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
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      signup = !signup;
                      error = null;
                    }),
              child: Text(
                signup
                    ? 'Already registered? Sign in'
                    : 'Create a retailer account',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class StorePage extends StatefulWidget {
  final User user;
  const StorePage({super.key, required this.user});
  @override
  State<StorePage> createState() => _StorePageState();
}

class _StorePageState extends State<StorePage> {
  final form = GlobalKey<FormState>();
  final fields = List.generate(7, (_) => TextEditingController());
  final labels = [
    'Owner/contact name',
    'Store name',
    'Mobile number',
    'Street / area',
    'City',
    'PIN code',
    'Brands sold (optional)',
  ];
  bool busy = false;
  String? error;
  late final DocumentReference<Map<String, dynamic>> doc;
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;
  @override
  void initState() {
    super.initState();
    doc = FirebaseFirestore.instance
        .collection('retailerApplications')
        .doc(widget.user.uid);
    stream = doc.snapshots();
  }

  @override
  void dispose() {
    for (final f in fields) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> save({bool publish = false}) async {
    if (!form.currentState!.validate()) {
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await doc
          .set({
            'ownerUid': widget.user.uid,
            'contactName': fields[0].text.trim(),
            'storeName': fields[1].text.trim(),
            'phone': fields[2].text.trim(),
            'address': fields[3].text.trim(),
            'city': fields[4].text.trim(),
            'pin': fields[5].text.trim(),
            'brands': fields[6].text.trim(),
            'status': 'pending',
            'createdAt': FieldValue.serverTimestamp(),
          })
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not confirm submission. Check connection and Firestore rules. If a pending application appears, it was saved.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
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

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your store'),
      actions: [
        TextButton(
          onPressed: busy ? null : logout,
          child: const Text('Sign out'),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Cannot load your application. Check connection and publish the retailer Firestore rules, then reopen the app.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snapshot.data!.data();
            if (data != null) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const SnapWearHero(
                    eyebrow: 'SNAPWEAR PARTNER',
                    title: 'Your store. Your style.',
                    subtitle: 'Manage your collection and prepare customer orders from one place.',
                    icon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    data['storeName'] as String? ?? 'Your store',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Application status: ${data['status'] ?? 'pending'}'),
                  const SizedBox(height: 12),
                  const Text(
                    'Keep your products and stock up to date. Use Customer Orders to prepare new orders; ready orders are assigned automatically to available riders.',
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DraftsPage(uid: widget.user.uid),
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: const Text('MANAGE PRODUCT DRAFTS'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ClothingOrdersPage(retailer: true),
                      ),
                    ),
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('CUSTOMER ORDERS'),
                  ),
                  const SizedBox(height: 24),
                  Text('${data['address']}\n${data['city']} · ${data['pin']}'),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Register your store',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Store details stay private while your application is pending.',
                ),
                const SizedBox(height: 24),
                Form(
                  key: form,
                  child: Column(
                    children: List.generate(
                      fields.length,
                      (i) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: fields[i],
                          enabled: !busy,
                          maxLength: i == 3 ? 300 : 120,
                          keyboardType: i == 2 || i == 5
                              ? TextInputType.phone
                              : TextInputType.text,
                          decoration: InputDecoration(labelText: labels[i]),
                          validator: (v) {
                            final value = v?.trim() ?? '';
                            if (i == 6) {
                              return null;
                            }
                            if (value.isEmpty) {
                              return 'Required';
                            }
                            if (i == 2 &&
                                !RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                              return 'Enter a 10-digit Indian mobile number';
                            }
                            if (i == 5 &&
                                !RegExp(r'^[1-9]\d{5}$').hasMatch(value)) {
                              return 'Enter a 6-digit PIN code';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                if (error != null)
                  Text(error!, style: const TextStyle(color: Colors.red)),
                FilledButton(
                  onPressed: busy ? null : () => save(),
                  child: Text(busy ? 'Submitting…' : 'SUBMIT FOR REVIEW'),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

class DraftsPage extends StatelessWidget {
  final String uid;
  const DraftsPage({super.key, required this.uid});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Product drafts')),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProductForm(uid: uid)),
      ),
      icon: const Icon(Icons.add),
      label: const Text('Add product'),
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('retailerApplications')
          .doc(uid)
          .collection('products')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Cannot load drafts. Check connection and retailer rules.',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        if (docs.isEmpty) {
          return const Center(
            child: Text('No drafts yet. Add your first product.'),
          );
        }
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: docs.map((doc) {
            final data = doc.data();
            final variants = (data['variants'] as List? ?? [])
                .whereType<Map>()
                .toList();
            final stock = variants.fold<int>(
              0,
              (total, item) => total + ((item['stock'] as num?)?.toInt() ?? 0),
            );
            return Card(
              child: ListTile(
                title: Text(data['name'] as String? ?? 'Product'),
                subtitle: Text(
                  '₹${data['price']} · $stock in stock · Private draft',
                ),
                trailing: const Icon(Icons.edit_outlined),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductForm(uid: uid, productId: doc.id, initial: data),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    ),
  );
}

Future<void> quickStock(
  BuildContext context,
  String uid,
  String id,
  Map<String, dynamic> initial,
) async {
  final variants = (initial['variants'] as List? ?? [])
      .whereType<Map>()
      .toList();
  final controllers = variants
      .map((v) => TextEditingController(text: '${v['stock'] ?? 0}'))
      .toList();
  final form = GlobalKey<FormState>();
  bool busy = false, closed = false;
  String? error;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setSheet) => AlertDialog(
        title: const Text('Quick stock update'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(initial['name'] as String? ?? 'Product'),
                  const SizedBox(height: 12),
                  const Text(
                    'Updates stock in the private draft and existing live listing together.',
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(
                    variants.length,
                    (i) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: controllers[i],
                        enabled: !busy,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText:
                              '${variants[i]['size']} / ${variants[i]['color']}',
                        ),
                        validator: (s) {
                          final n = int.tryParse(s ?? '');
                          return n == null || n < 0 || n > 1000000
                              ? 'Enter stock from 0 to 1000000'
                              : null;
                        },
                      ),
                    ),
                  ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: busy
                ? null
                : () {
                    closed = true;
                    Navigator.pop(dialogContext);
                  },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: busy
                ? null
                : () async {
                    if (!form.currentState!.validate()) {
                      return;
                    }
                    setSheet(() {
                      busy = true;
                      error = null;
                    });
                    try {
                      final db = FirebaseFirestore.instance;
                      final draft = db
                          .collection('retailerApplications')
                          .doc(uid)
                          .collection('products')
                          .doc(id);
                      final live = db
                          .collection('publishedProducts')
                          .doc('${uid}_$id');
                      await db
                          .runTransaction((tx) async {
                            final latest = await tx.get(draft),
                                listing = await tx.get(live);
                            if (!latest.exists ||
                                latest.data()?['updatedAt'] !=
                                    initial['updatedAt']) {
                              throw StateError(
                                'Stock changed. Close and reopen this product.',
                              );
                            }
                            final stockByKey = <String, int>{
                              for (var i = 0; i < variants.length; i++)
                                '${variants[i]['size']}|${variants[i]['color']}':
                                    int.parse(controllers[i].text),
                            };
                            final changed = variants
                                .map(
                                  (v) => <String, dynamic>{
                                    ...Map<String, dynamic>.from(v),
                                    'stock':
                                        stockByKey['${v['size']}|${v['color']}'],
                                  },
                                )
                                .toList();
                            List<Map<String, dynamic>>? changedLive;
                            if (listing.exists) {
                              final current =
                                  (listing.data()?['variants'] as List? ?? [])
                                      .whereType<Map>()
                                      .toList();
                              final keys = current
                                  .map((v) => '${v['size']}|${v['color']}')
                                  .toSet();
                              if (keys.length != stockByKey.length ||
                                  !keys.containsAll(stockByKey.keys)) {
                                throw StateError(
                                  'Live sizes differ from the draft. Edit and republish the product first.',
                                );
                              }
                              changedLive = current
                                  .map(
                                    (v) => <String, dynamic>{
                                      ...Map<String, dynamic>.from(v),
                                      'stock':
                                          stockByKey['${v['size']}|${v['color']}'],
                                    },
                                  )
                                  .toList();
                            }
                            tx.update(draft, {
                              'variants': changed,
                              'updatedAt': FieldValue.serverTimestamp(),
                            });
                            if (changedLive != null) {
                              tx.update(live, {
                                'variants': changedLive,
                                'updatedAt': FieldValue.serverTimestamp(),
                              });
                            }
                          })
                          .timeout(const Duration(seconds: 20));
                      if (dialogContext.mounted) {
                        closed = true;
                        Navigator.pop(dialogContext);
                      }
                    } catch (e) {
                      if (!closed && dialogContext.mounted) {
                        setSheet(() => error = 'Could not save: $e');
                      }
                    } finally {
                      if (!closed && dialogContext.mounted) {
                        setSheet(() => busy = false);
                      }
                    }
                  },
            child: Text(busy ? 'Saving…' : 'Save stock'),
          ),
        ],
      ),
    ),
  );
  for (final controller in controllers) {
    controller.dispose();
  }
}

class ProductStepView extends StatelessWidget {
  final int index;
  final List<Widget> children;
  const ProductStepView({
    super.key,
    required this.index,
    required this.children,
  });
  @override
  Widget build(BuildContext context) => Column(
    children: List.generate(
      children.length,
      (i) => Offstage(offstage: i != index, child: children[i]),
    ),
  );
}

class VariantFields {
  final size = TextEditingController(),
      color = TextEditingController(),
      stock = TextEditingController();
  VariantFields([Map? data]) {
    size.text = data?['size']?.toString() ?? '';
    color.text = data?['color']?.toString() ?? '';
    stock.text = data?['stock']?.toString() ?? '0';
  }
  void dispose() {
    size.dispose();
    color.dispose();
    stock.dispose();
  }
}

class ProductForm extends StatefulWidget {
  final String uid;
  final String? productId;
  final Map<String, dynamic>? initial;
  final bool duplicate;
  const ProductForm({
    super.key,
    required this.uid,
    this.productId,
    this.initial,
    this.duplicate = false,
  });
  @override
  State<ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<ProductForm> {
  final form = GlobalKey<FormState>(), stockForm = GlobalKey<FormState>();
  int step = 0;
  String productCollection = 'Unisex';
  Uint8List? previewPhoto;
  final name = TextEditingController(),
      brand = TextEditingController(),
      category = TextEditingController(),
      price = TextEditingController(),
      description = TextEditingController(),
      photo = TextEditingController();
  final variants = <VariantFields>[];
  late final DocumentReference<Map<String, dynamic>> doc;
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final data = widget.initial ?? <String, dynamic>{};
    productCollection =
        [
          'Women',
          'Men',
          'Accessories',
          'Kids',
          'Unisex',
        ].contains(data['collection'])
        ? data['collection'] as String
        : 'Unisex';
    final controllers = {
      'name': name,
      'brand': brand,
      'category': category,
      'price': price,
      'description': description,
      'photoUrl': photo,
    };
    controllers.forEach(
      (key, controller) => controller.text = data[key]?.toString() ?? '',
    );
    for (final item in (data['variants'] as List? ?? []).whereType<Map>()) {
      variants.add(VariantFields(item));
    }
    if (variants.isEmpty) {
      variants.add(VariantFields());
    }
    if (widget.duplicate) {
      name.text = '${name.text} (copy)';
      for (final v in variants) {
        v.stock.text = '0';
      }
    }
    final collection = FirebaseFirestore.instance
        .collection('retailerApplications')
        .doc(widget.uid)
        .collection('products');
    doc = widget.productId == null
        ? collection.doc()
        : collection.doc(widget.productId);
  }

  @override
  void dispose() {
    for (final c in [name, brand, category, price, description, photo]) {
      c.dispose();
    }
    for (final v in variants) {
      v.dispose();
    }
    super.dispose();
  }

  String? requiredText(String? value) =>
      (value?.trim().isEmpty ?? true) ? 'Required' : null;
  Future<void> save({bool publish = false}) async {
    if (!form.currentState!.validate()) {
      setState(() => step = 0);
      return;
    }
    if (!stockForm.currentState!.validate()) {
      setState(() => step = 1);
      return;
    }
    final seen = <String>{};
    for (final variant in variants) {
      final key =
          '${variant.size.text.trim().toLowerCase()}|${variant.color.text.trim().toLowerCase()}';
      if (!seen.add(key)) {
        setState(
          () => error = 'Each size and colour combination must be unique.',
        );
        return;
      }
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = {
        'ownerUid': widget.uid,
        'name': name.text.trim(),
        'brand': brand.text.trim(),
        'category': category.text.trim(),
        'collection': productCollection,
        'price': double.parse(price.text.trim()),
        'description': description.text.trim(),
        'photoUrl': photo.text.trim(),
        'status': 'draft',
        'variants': variants
            .map(
              (v) => {
                'size': v.size.text.trim(),
                'color': v.color.text.trim(),
                'stock': int.parse(v.stock.text.trim()),
              },
            )
            .toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance
          .runTransaction((transaction) async {
            final latest = await transaction.get(doc);
            if (latest.exists &&
                latest.data()?['updatedAt'] != widget.initial?['updatedAt']) {
              throw StateError(
                'Stock or draft changed. Reopen this product before saving or publishing.',
              );
            }
            Map<String, dynamic>? publication;
            if (publish) {
              if (photo.text.trim().isEmpty) {
                throw StateError(
                  'Add an HTTPS product photo before publishing.',
                );
              }
              final store = await transaction.get(doc.parent.parent!);
              if (store.data()?['status'] != 'approved') {
                throw StateError(
                  'Your store must be approved before publishing.',
                );
              }
              publication = {
                ...data,
                'status': 'published',
                'productId': doc.id,
                'storeName': store.data()!['storeName'],
              };
            }
            transaction.set(doc, data);
            if (publication != null) {
              transaction.set(
                FirebaseFirestore.instance
                    .collection('publishedProducts')
                    .doc('${widget.uid}_${doc.id}'),
                publication,
              );
            }
          })
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not confirm save: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Future<void> unpublish() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove customer listing?'),
        content: const Text('Your private draft will remain.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
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
      await FirebaseFirestore.instance
          .collection('publishedProducts')
          .doc('${widget.uid}_${doc.id}')
          .delete()
          .timeout(const Duration(seconds: 20));
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = 'Could not confirm removal: $e');
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  Widget field(
    TextEditingController controller,
    String label, {
    int max = 120,
    String? Function(String?)? validator,
    TextInputType? keyboard,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !busy,
      maxLength: max,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: validator ?? requiredText,
    ),
  );
  Future<void> choosePreview() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null) {
        return;
      }
      final bytes = await picked.readAsBytes();
      if (bytes.length > 8 * 1024 * 1024) {
        throw StateError('Choose a photo smaller than 8 MB.');
      }
      if (mounted) {
        setState(() => previewPhoto = bytes);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not preview this photo. Choose another image.',
        );
      }
    }
  }

  void nextStep() {
    if (step == 0 && !form.currentState!.validate()) {
      return;
    }
    if (step == 1 && !stockForm.currentState!.validate()) {
      return;
    }
    setState(() {
      step++;
      error = null;
    });
  }

  Widget photoPreview() {
    if (previewPhoto != null) {
      return Image.memory(previewPhoto!, height: 220, fit: BoxFit.contain);
    }
    if (photo.text.trim().isNotEmpty) {
      return Image.network(
        photo.text.trim(),
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        height: 220,
        fit: BoxFit.contain,
        errorBuilder: (_, e, stack) => const SizedBox(
          height: 100,
          child: Center(child: Text('Photo link could not load.')),
        ),
      );
    }
    return const SizedBox(
      height: 120,
      child: Center(
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 56,
          color: snapForest,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.duplicate
              ? 'Duplicate product'
              : widget.productId == null
              ? 'Add product'
              : 'Edit product',
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SnapWearHero(
                eyebrow: 'YOUR COLLECTION',
                title: 'Ready for the shop window.',
                subtitle: 'Details → price and stock → preview and publish.',
                icon: Icons.checkroom_outlined,
              ),
              const SizedBox(height: 24),
              Row(
                children: List.generate(
                  3,
                  (i) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Column(
                        children: [
                          LinearProgressIndicator(value: i <= step ? 1 : 0),
                          const SizedBox(height: 8),
                          Text(
                            ['1. Details', '2. Stock', '3. Preview'][i],
                            style: TextStyle(
                              fontWeight: i == step
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ProductStepView(
                index: step,
                children: [
                  Form(
                    key: form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field(name, 'Product name'),
                        field(brand, 'Brand'),
                        field(category, 'Category'),
                        DropdownButtonFormField<String>(
                          initialValue: productCollection,
                          decoration: const InputDecoration(
                            labelText: 'Collection',
                          ),
                          items:
                              ['Women', 'Men', 'Accessories', 'Kids', 'Unisex']
                                  .map(
                                    (v) => DropdownMenuItem(
                                      value: v,
                                      child: Text(v),
                                    ),
                                  )
                                  .toList(),
                          onChanged: busy
                              ? null
                              : (v) => setState(() => productCollection = v!),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          children:
                              [
                                    'T-Shirts',
                                    'Shirts',
                                    'Hoodies',
                                    'Jeans',
                                    'Dresses',
                                  ]
                                  .map(
                                    (c) => ActionChip(
                                      label: Text(c),
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => category.text = c,
                                            ),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 16),
                        field(description, 'Description', max: 2000),
                        field(
                          photo,
                          'Published photo HTTPS URL',
                          max: 2000,
                          validator: (v) {
                            if (v?.trim().isEmpty ?? true) {
                              return null;
                            }
                            final uri = Uri.tryParse(v!.trim());
                            return uri != null &&
                                    uri.scheme == 'https' &&
                                    uri.host.isNotEmpty
                                ? null
                                : 'Enter an HTTPS image URL';
                          },
                        ),
                        OutlinedButton.icon(
                          onPressed: busy ? null : choosePreview,
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Preview gallery photo'),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Gallery selection is a local preview only. To publish, use a hosted HTTPS photo link until photo storage is connected.',
                        ),
                      ],
                    ),
                  ),
                  Form(
                    key: stockForm,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        field(
                          price,
                          'Price in rupees',
                          keyboard: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (v) {
                            final n = double.tryParse(v?.trim() ?? '');
                            return n == null ||
                                    !n.isFinite ||
                                    n <= 0 ||
                                    n > 1000000 ||
                                    n != (n * 100).round() / 100
                                ? 'Enter a positive price with at most 2 decimals'
                                : null;
                          },
                        ),
                        const Text(
                          'One row for each size and colour.',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        ...List.generate(
                          variants.length,
                          (i) => Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  Text('Variant ${i + 1}'),
                                  field(variants[i].size, 'Size', max: 40),
                                  field(variants[i].color, 'Colour', max: 60),
                                  field(
                                    variants[i].stock,
                                    'Available stock',
                                    max: 7,
                                    keyboard: TextInputType.number,
                                    validator: (v) {
                                      final n = int.tryParse(v?.trim() ?? '');
                                      return n == null || n < 0 || n > 1000000
                                          ? 'Enter stock from 0 to 1000000'
                                          : null;
                                    },
                                  ),
                                  if (variants.length > 1)
                                    TextButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => variants
                                                  .removeAt(i)
                                                  .dispose(),
                                            ),
                                      child: const Text('Remove variant'),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: busy || variants.length >= 30
                              ? null
                              : () => setState(
                                  () => variants.add(VariantFields()),
                                ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add size / colour'),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              photoPreview(),
                              const SizedBox(height: 16),
                              Text(
                                name.text,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: snapForest,
                                ),
                              ),
                              Text('${brand.text} · ${category.text}'),
                              const SizedBox(height: 12),
                              Text(
                                '₹${price.text}',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(description.text),
                              const SizedBox(height: 16),
                              ...variants.map(
                                (v) => Text(
                                  '${v.size.text} / ${v.color.text} · ${v.stock.text} available',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (previewPhoto != null)
                        const Text(
                          'Gallery image above is not uploaded. Customers will see the HTTPS photo link.',
                        ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: busy ? null : () => save(),
                        child: Text(busy ? 'Saving…' : 'SAVE PRIVATE DRAFT'),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: busy ? null : () => save(publish: true),
                        child: const Text('PUBLISH / UPDATE LISTING'),
                      ),
                      if (widget.productId != null)
                        TextButton(
                          onPressed: busy ? null : unpublish,
                          child: const Text('REMOVE CUSTOMER LISTING'),
                        ),
                    ],
                  ),
                ],
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (step > 0)
                    OutlinedButton(
                      onPressed: busy ? null : () => setState(() => step--),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  if (step < 2)
                    FilledButton(
                      onPressed: busy ? null : nextStep,
                      child: const Text('Continue'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
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
            const SizedBox(height: 12),
            Chip(
              label: Text((d['status'] as String).replaceAll('_', ' ')),
              avatar: const Icon(Icons.local_shipping_outlined, size: 18),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Order: ${widget.id}',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            if (!['cancelled', 'rejected', 'delivered'].contains(d['status']))
              Text(
                d['riderName'] == null
                    ? 'A rider will be assigned automatically when this order is ready.'
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

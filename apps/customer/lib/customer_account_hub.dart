import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'main.dart'
    show
        ProfileDetails,
        profileDetails,
        AccountStorage,
        AccountPage,
        EditProfilePage,
        ClothingOrdersPage,
        DeleteAccountPage,
        RetailerProductPage,
        EmailVerificationCard;
import 'royal_design.dart';
import 'complete_my_look.dart';

final customerLargeText = ValueNotifier<bool>(false);
final customerReducedMotion = ValueNotifier<bool>(false);

Future<void> saveCustomerOption(String key, dynamic value) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Sign in to save your preferences.');
  await FirebaseFirestore.instance.doc('users/${user.uid}').set({
    key: value,
  }, SetOptions(merge: true));
}

void accountOpen(BuildContext context, Widget page) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
Future<void> accountMessage(
  BuildContext context,
  String title,
  String message,
) => showDialog<void>(
  context: context,
  builder: (c) => AlertDialog(
    title: Text(title),
    content: Text(message),
    actions: [
      TextButton(onPressed: () => Navigator.pop(c), child: const Text('Done')),
    ],
  ),
);

Future<void> accountLoginAndReload(BuildContext context, Widget page) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
  if (context.mounted && FirebaseAuth.instance.currentUser != null) {
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
  }
}

class CustomerAccountHub extends StatelessWidget {
  const CustomerAccountHub({super.key});
  Widget row(
    BuildContext c,
    IconData icon,
    String title,
    String subtitle,
    Widget page,
  ) => ListTile(
    leading: Icon(icon, color: royalInk),
    title: Text(title),
    subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => accountOpen(c, page),
  );
  Widget section(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 10),
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: royalInk,
                ),
              ),
            ),
            ...children,
          ],
        ),
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Your SnapWear'),
      actions: [
        IconButton(
          tooltip: 'Help',
          onPressed: () => accountOpen(context, const CustomerHelpPage()),
          icon: const Icon(Icons.help_outline),
        ),
      ],
    ),
    body: StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      initialData: FirebaseAuth.instance.currentUser,
      builder: (context, auth) => ValueListenableBuilder<ProfileDetails>(
        valueListenable: profileDetails,
        builder: (context, details, _) {
          final user = auth.data;
          final display = details.name.isNotEmpty
              ? details.name
              : user?.displayName ?? 'Your style starts here';
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 780),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: royalInk,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 28,
                              backgroundColor: const Color(0xFFECD4A5),
                              child: Text(
                                user == null
                                    ? 'S'
                                    : (display.isEmpty ? 'S' : display.characters.first.toUpperCase()),
                                style: const TextStyle(
                                  color: royalInk,
                                  fontSize: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    display,
                                    style: const TextStyle(
                                      fontFamily: 'SnapSerif',
                                      color: royalCream,
                                      fontSize: 30,
                                    ),
                                  ),
                                  Text(
                                    user == null
                                        ? 'Guest · explore your local style'
                                        : user.email ?? '',
                                    style: const TextStyle(
                                      color: Color(0xFFECD4A5),
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          style: TextButton.styleFrom(
                            foregroundColor: royalCream,
                          ),
                          onPressed: () => accountOpen(
                            context,
                            user == null
                                ? const AccountPage()
                                : const EditProfilePage(),
                          ),
                          icon: Icon(
                            user == null ? Icons.login : Icons.edit_outlined,
                            size: 17,
                          ),
                          label: Text(
                            user == null
                                ? 'Log in / Create account'
                                : 'Edit profile',
                          ),
                        ),
                        const Divider(color: Color(0xFF57706A)),
                        const Text(
                          'A wardrobe of possibilities. A neighbourhood of boutiques.',
                          style: TextStyle(
                            color: Color(0xFFECD4A5),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  LayoutBuilder(
                    builder: (context, bounds) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final entry in [
                          (
                            Icons.receipt_long_outlined,
                            'Orders',
                            const ClothingOrdersPage(),
                          ),
                          (
                            Icons.favorite_border,
                            'Saved pieces',
                            const SavedRetailerItemsPage(),
                          ),
                          (
                            Icons.location_on_outlined,
                            'Addresses',
                            const CustomerAddressBook(),
                          ),
                          (
                            Icons.auto_awesome,
                            'My looks',
                            const CompleteMyLookPage(),
                          ),
                        ])
                          SizedBox(
                            width:
                                (bounds.maxWidth -
                                    (bounds.maxWidth < 420 ? 10 : 30)) /
                                (bounds.maxWidth < 420 ? 2 : 4),
                            child: Card(
                              child: InkWell(
                                borderRadius: BorderRadius.circular(18),
                                onTap: () => accountOpen(context, entry.$3),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18,
                                    horizontal: 8,
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(entry.$1, color: royalGold),
                                      const SizedBox(height: 8),
                                      Text(
                                        entry.$2,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (user != null) const EmailVerificationCard(),
                  section('Your shopping', [
                    row(
                      context,
                      Icons.local_shipping_outlined,
                      'Orders, tracking & receipts',
                      'Follow delivery, cancellation reasons and bills',
                      const ClothingOrdersPage(),
                    ),
                    row(
                      context,
                      Icons.favorite_border,
                      'Saved fashion pieces',
                      'Real boutique products you want to revisit',
                      const SavedRetailerItemsPage(),
                    ),
                    row(
                      context,
                      Icons.auto_awesome,
                      'Complete My Look',
                      'Build an outfit within your size and budget',
                      const CompleteMyLookPage(),
                    ),
                    row(
                      context,
                      Icons.home_outlined,
                      'Address book',
                      'Home, work and other delivery addresses',
                      const CustomerAddressBook(),
                    ),
                  ]),
                  section('Make it yours', [
                    row(
                      context,
                      Icons.tune,
                      'Style & fit preferences',
                      'Your usual size, occasion and outfit budget',
                      const CustomerStylePreferences(),
                    ),
                    row(
                      context,
                      Icons.accessibility_new,
                      'Reading & motion',
                      'Larger text and reduced animations',
                      const CustomerAccessibilityPage(),
                    ),
                  ]),
                  section('Payments & help', [
                    ListTile(
                      leading: const Icon(Icons.payments_outlined),
                      title: const Text('Payment options'),
                      subtitle: const Text(
                        'Cash on delivery · online setup pending',
                        style: TextStyle(fontSize: 12),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => accountMessage(
                        context,
                        'Payments on SnapWear',
                        'Cash on delivery is available in this test build. Pay only the order amount shown at checkout. Online payments, saved cards, wallets and reward balances are not connected.',
                      ),
                    ),
                    row(
                      context,
                      Icons.help_outline,
                      'Shopping help',
                      'Sizes, delivery codes, cancellation and payments',
                      const CustomerHelpPage(),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: const Text('About SnapWear'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => accountMessage(
                        context,
                        'SnapWear',
                        'Fashion near you. Delivered beautifully.\n\nDiscover participating clothing boutiques and shop their published stock. This is a local review build. Live payments, GPS tracking, SMS and email delivery require production setup.',
                      ),
                    ),
                  ]),
                  section('Account', [
                    if (user != null) ...[
                      ListTile(
                        leading: const Icon(Icons.logout),
                        title: const Text('Log out'),
                        onTap: () async {
                          try {
                            if (AccountStorage.ready) {
                              await AccountStorage.flush();
                            }
                            await FirebaseAuth.instance.signOut();
                            if (context.mounted) {
                              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const AccountPage(startup: true),
                                ),
                                (_) => false,
                              );
                            }
                          } catch (_) {
                            if (context.mounted) {
                              accountMessage(
                                context,
                                'Could not log out',
                                'Please try again.',
                              );
                            }
                          }
                        },
                      ),
                      row(
                        context,
                        Icons.delete_outline,
                        'Delete account',
                        'Review account deletion options',
                        const DeleteAccountPage(),
                      ),
                    ] else
                      row(
                        context,
                        Icons.login,
                        'Log in / Sign up',
                        'Save your addresses, fit and fashion pieces',
                        const AccountPage(),
                      ),
                  ]),
                  const SizedBox(height: 20),
                  const Text(
                    'SNAPWEAR · Your local style companion',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: royalGold, fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}

class SaveRetailerPieceButton extends StatelessWidget {
  final String productId;
  const SaveRetailerPieceButton({super.key, required this.productId});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return TextButton.icon(
        onPressed: () => accountOpen(context, const AccountPage()),
        icon: const Icon(Icons.favorite_border),
        label: const Text('Sign in to save this piece'),
      );
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.doc('users/${user.uid}').snapshots(),
      builder: (context, snapshot) {
        final saved = (snapshot.data?.data()?['savedListingIds'] as List? ?? [])
            .contains(productId);
        return TextButton.icon(
          onPressed: snapshot.hasError
              ? null
              : () async {
                  try {
                    await saveCustomerOption(
                      'savedListingIds',
                      saved
                          ? FieldValue.arrayRemove([productId])
                          : FieldValue.arrayUnion([productId]),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      accountMessage(
                        context,
                        'Could not save',
                        'Check your connection and try again.',
                      );
                    }
                  }
                },
          icon: Icon(saved ? Icons.favorite : Icons.favorite_border),
          label: Text(saved ? 'Saved to your pieces' : 'Save this piece'),
        );
      },
    );
  }
}

class SavedRetailerItemsPage extends StatelessWidget {
  const SavedRetailerItemsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Saved fashion pieces')),
      body: user == null
          ? Center(
              child: FilledButton(
                onPressed: () => accountLoginAndReload(context, const SavedRetailerItemsPage()),
                child: const Text('Log in to see saved pieces'),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('users/${user.uid}')
                  .snapshots(),
              builder: (context, saved) {
                if (saved.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load saved pieces. Please reopen this page.',
                    ),
                  );
                }
                if (!saved.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ids =
                    (saved.data!.data()?['savedListingIds'] as List? ?? [])
                        .whereType<String>()
                        .toSet();
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('publishedProducts')
                      .snapshots(),
                  builder: (context, products) {
                    if (products.hasError) {
                      return const Center(
                        child: Text('Could not load product availability.'),
                      );
                    }
                    if (!products.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final matches = products.data!.docs.where(
                      (d) => ids.contains(d.id),
                    );
                    return ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        if (ids.isEmpty)
                          const Text(
                            'Your next favourite belongs here. Open a boutique product and tap Save this piece.',
                          ),
                        ...matches.map(
                          (d) => Card(
                            child: ListTile(
                              leading: const Icon(Icons.checkroom),
                              title: Text(d.data()['name'] as String),
                              subtitle: Text(
                                '${d.data()['storeName']} · ₹${d.data()['price']}',
                              ),
                              trailing: IconButton(
                                tooltip: 'Remove saved piece',
                                icon: const Icon(Icons.favorite),
                                onPressed: () =>
                                    saveCustomerOption(
                                      'savedListingIds',
                                      FieldValue.arrayRemove([d.id]),
                                    ).catchError((Object _) {
                                      if (context.mounted) {
                                        accountMessage(
                                          context,
                                          'Could not remove',
                                          'Please try again.',
                                        );
                                      }
                                    }),
                              ),
                              onTap: () => accountOpen(
                                context,
                                RetailerProductPage(id: d.id),
                              ),
                            ),
                          ),
                        ),
                        ...ids
                            .where(
                              (id) =>
                                  !products.data!.docs.any((d) => d.id == id),
                            )
                            .map(
                              (id) => ListTile(
                                title: const Text(
                                  'A saved piece is no longer published',
                                ),
                                trailing: TextButton(
                                  onPressed: () async {
                                    try {
                                      await saveCustomerOption(
                                        'savedListingIds',
                                        FieldValue.arrayRemove([id]),
                                      );
                                    } catch (_) {
                                      if (context.mounted) {
                                        accountMessage(
                                          context,
                                          'Could not remove',
                                          'Please try again.',
                                        );
                                      }
                                    }
                                  },
                                  child: const Text('Remove'),
                                ),
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
}

class CustomerAddressBook extends StatelessWidget {
  const CustomerAddressBook({super.key});
  Future<void> add(BuildContext context) async {
    final form = GlobalKey<FormState>();
    final label = TextEditingController(text: 'Home'),
        street = TextEditingController(),
        city = TextEditingController(),
        pin = TextEditingController();
    bool busy = false;
    String? error;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, update) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(c).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Form(
              key: form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Save an address',
                    style: TextStyle(fontFamily: 'SnapSerif', fontSize: 28),
                  ),
                  for (final entry in [
                    (label, 'Label · Home / Work / Other'),
                    (street, 'House, street and area'),
                    (city, 'City'),
                    (pin, 'PIN'),
                  ])
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        controller: entry.$1,
                        maxLength: entry.$1 == pin ? 6 : 300,
                        keyboardType: entry.$1 == pin
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: InputDecoration(labelText: entry.$2),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Required'
                            : entry.$1 == pin &&
                                  !RegExp(r'^[1-9][0-9]{5}$').hasMatch(v)
                            ? 'Enter a valid 6-digit PIN'
                            : null,
                      ),
                    ),
                  if (error != null)
                    Text(error!, style: const TextStyle(color: Colors.red)),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            if (!form.currentState!.validate()) return;
                            update(() {
                              busy = true;
                              error = null;
                            });
                            try {
                              await saveCustomerOption(
                                'savedAddresses',
                                FieldValue.arrayUnion([
                                  {
                                    'label': label.text.trim(),
                                    'street': street.text.trim(),
                                    'city': city.text.trim(),
                                    'pin': pin.text.trim(),
                                  },
                                ]),
                              );
                              if (c.mounted) Navigator.pop(c);
                            } catch (_) {
                              if (c.mounted) {
                                update(() {
                                  busy = false;
                                  error = 'Could not save. Check your connection and try again.';
                                });
                              }
                            }
                          },
                    child: Text(busy ? 'Saving…' : 'Save address'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The closing sheet finishes its animation before releasing field controllers.
    await Future<void>.delayed(const Duration(milliseconds: 350));
    label.dispose();
    street.dispose();
    city.dispose();
    pin.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('Address book')),
      body: user == null
          ? Center(
              child: FilledButton(
                onPressed: () => accountLoginAndReload(context, const CustomerAddressBook()),
                child: const Text('Log in to save addresses'),
              ),
            )
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .doc('users/${user.uid}')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load addresses. Please reopen this page.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final addresses =
                    (snapshot.data!.data()?['savedAddresses'] as List? ?? [])
                        .whereType<Map>()
                        .toList();
                return ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    FilledButton.icon(
                      onPressed: () => add(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Add address'),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Use an address to update your profile delivery address. Review the full address and PIN again at checkout.',
                    ),
                    if (addresses.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No saved addresses yet.'),
                      ),
                    ...addresses.map(
                      (a) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${a['label']}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${a['street']}\n${a['city']} · ${a['pin']}',
                              ),
                              Wrap(
                                children: [
                                  TextButton(
                                    onPressed: () async {
                                      final old = profileDetails.value;
                                      try {
                                        await AccountStorage.saveProfile(
                                          ProfileDetails(
                                            name: old.name,
                                            email: old.email,
                                            phone: old.phone,
                                            address:
                                                '${a['street']}, ${a['city']} - ${a['pin']}',
                                          ),
                                        );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                const SnackBar(
                                                  content: Text(
                                                    'Profile delivery address updated.',
                                                  ),
                                                ),
                                              );
                                        }
                                      } catch (_) {
                                        if (context.mounted) {
                                          accountMessage(
                                            context,
                                            'Could not update address',
                                            'Wait for your account to finish loading and try again.',
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Use for delivery'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      try {
                                        await saveCustomerOption(
                                          'savedAddresses',
                                          FieldValue.arrayRemove([a]),
                                        );
                                      } catch (_) {
                                        if (context.mounted) {
                                          accountMessage(
                                            context,
                                            'Could not remove address',
                                            'Please try again.',
                                          );
                                        }
                                      }
                                    },
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class CustomerStylePreferences extends StatefulWidget {
  const CustomerStylePreferences({super.key});
  @override
  State<CustomerStylePreferences> createState() =>
      _CustomerStylePreferencesState();
}

class _CustomerStylePreferencesState extends State<CustomerStylePreferences> {
  String size = 'Any', occasion = 'Casual';
  double budget = 5000;
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .doc('users/${user.uid}')
            .get();
        final p = doc.data()?['stylePreferences'] as Map? ?? {};
        if (mounted) {
          size = ['Any', 'XS', 'S', 'M', 'L', 'XL', 'XXL'].contains(p['size'])
              ? p['size']
              : 'Any';
          occasion =
              ['Office', 'College', 'Wedding', 'Casual'].contains(p['occasion'])
              ? p['occasion']
              : 'Casual';
          budget = ((p['budget'] as num?)?.toDouble() ?? 5000).clamp(
            500,
            20000,
          );
        }
      }
    } catch (_) {
      error = 'Could not load preferences. Reopen this page to try again.';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Style & fit preferences')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Make every look more you.',
                style: TextStyle(fontFamily: 'SnapSerif', fontSize: 32),
              ),
              const Text(
                'Complete My Look uses these as starting preferences. Sizes vary by brand; check each product before ordering.',
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: size,
                decoration: const InputDecoration(
                  labelText: 'Usual clothing size',
                ),
                items: ['Any', 'XS', 'S', 'M', 'L', 'XL', 'XXL']
                    .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                    .toList(),
                onChanged: (v) => setState(() => size = v!),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                children: ['Office', 'College', 'Wedding', 'Casual']
                    .map(
                      (v) => ChoiceChip(
                        label: Text(v),
                        selected: occasion == v,
                        onSelected: (_) => setState(() => occasion = v),
                      ),
                    )
                    .toList(),
              ),
              Text('Outfit item budget · ₹${budget.toInt()}'),
              Slider(
                value: budget,
                min: 500,
                max: 20000,
                divisions: 39,
                onChanged: (v) => setState(() => budget = v),
              ),
              if (error != null) Text(error!),
              FilledButton(
                onPressed: busy || error != null
                    ? null
                    : () async {
                        setState(() => busy = true);
                        try {
                          await saveCustomerOption('stylePreferences', {
                            'size': size,
                            'occasion': occasion,
                            'budget': budget,
                          });
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Style preferences saved.'),
                              ),
                            );
                          }
                        } catch (_) {
                          if (context.mounted) {
                            accountMessage(
                              context,
                              'Could not save preferences',
                              'Sign in and check your connection, then try again.',
                            );
                          }
                        } finally {
                          if (mounted) setState(() => busy = false);
                        }
                      },
                child: Text(busy ? 'Saving…' : 'Save preferences'),
              ),
            ],
          ),
  );
}

class CustomerAccessibilityPage extends StatelessWidget {
  const CustomerAccessibilityPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reading & motion')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Comfortable by design',
          style: TextStyle(fontFamily: 'SnapSerif', fontSize: 30),
        ),
        const Text(
          'These options apply across this app session. Your device accessibility settings are respected too.',
        ),
        ValueListenableBuilder<bool>(
          valueListenable: customerLargeText,
          builder: (_, value, _) => SwitchListTile(
            title: const Text('Larger text'),
            subtitle: const Text('Increase text size by 15%'),
            value: value,
            onChanged: (v) => customerLargeText.value = v,
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: customerReducedMotion,
          builder: (_, value, _) => SwitchListTile(
            title: const Text('Reduce motion'),
            subtitle: const Text(
              'Use shorter or no transitions where supported',
            ),
            value: value,
            onChanged: (v) => customerReducedMotion.value = v,
          ),
        ),
      ],
    ),
  );
}

class CustomerHelpPage extends StatelessWidget {
  const CustomerHelpPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Shopping help')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'How can we help?',
          style: TextStyle(fontFamily: 'SnapSerif', fontSize: 32),
        ),
        ...{
          'Where is my order?': 'Open Orders to see retailer preparation, rider assignment, pickup and delivery status. Live GPS is not connected in this review build.',
          'How do I choose my size?': 'Choose your size on the product page and review its description. Fit First filters available sizes; Complete My Look builds a same-boutique selection within your item budget.',
          'How do delivery codes work?': 'Your order page shows a delivery code. Share it with the rider only after receiving your clothes.',
          'Can I cancel my order?': 'Open the order to see whether cancellation is available at its current stage. If offered, choose the reason before submitting.',
          'Returns, exchanges and refunds': 'Return and exchange requests are not connected yet. This build does not process refunds or show an invented refund balance. Review the item details and size before placing an order.',
          'Where is my bill?': 'Open Orders and select Receipt & email bill. You can copy the receipt. Actual email delivery needs provider setup.',
          'How are nearby matches found?': 'Nearby item search uses your location only when you choose Use my location. It shows participating stores with reviewed coordinates and matching published stock.',
          'How do saved addresses work?': 'Save Home, Work or another address in Address book. Use for delivery updates your profile; review all checkout fields before confirming.',
        }.entries.map(
          (e) => Card(
            child: ExpansionTile(
              title: Text(e.key),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(e.value),
                ),
              ],
            ),
          ),
        ),
        FilledButton(
          onPressed: () => accountOpen(context, const ClothingOrdersPage()),
          child: const Text('Open my orders'),
        ),
        const SizedBox(height: 16),
        const Text(
          'Live support chat is not connected in this local review build.',
          style: TextStyle(fontSize: 12),
        ),
      ],
    ),
  );
}

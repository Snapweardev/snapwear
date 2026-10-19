import 'dart:ui' show PointerDeviceKind;

import 'customer_account_hub.dart';
import 'complete_my_look.dart';
import 'royal_design.dart';

import 'package:flutter/foundation.dart';

import 'local_auth_reset.dart'
    if (dart.library.js_interop) 'local_auth_reset_web.dart';
import 'customer_assistance.dart';
import 'connected_features.dart';
import 'customer_design.dart';
import 'snapwear_design.dart';
import 'startup_splash.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as latlong;
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

final profileDetails = ValueNotifier<ProfileDetails>(const ProfileDetails());

final demoOrders = ValueNotifier<List<DemoOrder>>([]);

final savedProducts = ValueNotifier<List<Product>>([]);

final messageKey = GlobalKey<ScaffoldMessengerState>();

class ClearMessagesOnNavigation extends NavigatorObserver {
  void clearMessages() {
    messageKey.currentState?.clearSnackBars();
    messageKey.currentState?.removeCurrentSnackBar();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    clearMessages();
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    clearMessages();
  }
}

const ink = snapForest;
const cream = snapCream;
const lime = snapPeach;

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

    AccountStorage.start();
    runApp(const SnapWearApp());
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Firebase could not start. Check your connection and '
                  'firebase_options.dart configuration, then restart the app.',
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SnapWearApp extends StatelessWidget {
  const SnapWearApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'SnapWear',
      scaffoldMessengerKey: messageKey,
      navigatorObservers: [ClearMessagesOnNavigation()],
      theme: snapWearTheme(fontFamily: GoogleFonts.manrope().fontFamily),
      builder: (context, child) => ValueListenableBuilder<bool>(
        valueListenable: customerLargeText,
        builder: (context, large, _) => ValueListenableBuilder<bool>(
          valueListenable: customerReducedMotion,
          builder: (context, reduced, _) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: large
                    ? TextScaler.linear(media.textScaler.scale(1) * 1.15)
                    : media.textScaler,
                disableAnimations: media.disableAnimations || reduced,
              ),
              child: RoyalFrame(child: StorageFeedback(child: child!)),
            );
          },
        ),
      ),
      home: const SnapWearOpening(child: AccountPage(startup: true)),
    );
  }
}

// ---------------- COLLECTION ----------------
const catalog = <Product>[
  Product(name: 'Classic T-Shirt', price: 799, icon: Icons.checkroom),
  Product(name: 'Denim Jacket', price: 1499, icon: Icons.shopping_bag),
  Product(name: 'Casual Shirt', price: 999, icon: Icons.dry_cleaning),
  Product(name: 'Hoodie', price: 1299, icon: Icons.layers),
];

class SampleCollectionPage extends StatefulWidget {
  const SampleCollectionPage({super.key});
  @override
  State<SampleCollectionPage> createState() => _HomePageState();
}

class _HomePageState extends State<SampleCollectionPage> {
  String category = 'All';
  final searchController = TextEditingController();

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  void clearFilters() {
    searchController.clear();
    setState(() => category = 'All');
  }

  Future<void> openCart() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CartPage()),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = searchController.text.trim().toLowerCase();
    final products = catalog.where((p) {
      final matchesCategory =
          category == 'All' ||
          (category == 'T-Shirts' && p.name.contains('T-Shirt')) ||
          (category == 'Shirts' && p.name == 'Casual Shirt') ||
          (category == 'Layers' &&
              (p.name.contains('Jacket') || p.name == 'Hoodie'));
      return matchesCategory && p.name.toLowerCase().contains(query);
    }).toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'SNAPWEAR.',
          style: TextStyle(
            fontFamily: 'SnapSerif',
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
            fontSize: 26,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Retailer products',
            icon: const Icon(Icons.storefront),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PublishedCataloguePage()),
            ),
          ),
          IconButton(
            tooltip: 'Nearby stores',
            icon: const Icon(Icons.map_outlined),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StoreDiscoveryPage()),
            ),
          ),
          IconButton(
            tooltip: 'Open cart',
            onPressed: openCart,
            icon: const CartBadge(),
          ),
          const SizedBox(width: 14),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const Text(
            'EVERYDAY WEAR. YOUR WAY.',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 18),
          Entrance(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ink,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: lime,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: const Text(
                      'THE SNAPWEAR EDIT',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'Wear your\nnext mood.',
                    style: TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 46,
                      height: 1.05,
                      letterSpacing: -2,
                      fontWeight: FontWeight.w700,
                      color: cream,
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Fresh staples. Endless possibilities.',
                    style: TextStyle(color: Color(0xFFB8BDB2), fontSize: 13),
                  ),
                  const SizedBox(height: 18),
                  const Row(
                    children: [
                      Text(
                        'EXPLORE THE COLLECTION',
                        style: TextStyle(
                          color: lime,
                          fontSize: 11,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 10),
                      Icon(Icons.south_east, color: lime, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your daily rotation',
                style: TextStyle(
                  fontFamily: 'SnapSerif',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.8,
                ),
              ),
              Text(
                '${products.length} pieces',
                style: const TextStyle(fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: searchController,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search your next look',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        searchController.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['All', 'T-Shirts', 'Shirts', 'Layers']
                  .map(
                    (name) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(name),
                        selected: category == name,
                        selectedColor: lime,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => category = name),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          if (products.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  const Icon(Icons.search_off, size: 38),
                  const SizedBox(height: 12),
                  const Text(
                    'No matching pieces',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Try another name or category.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: clearFilters,
                    child: const Text('SHOW ALL PRODUCTS'),
                  ),
                ],
              ),
            ),
          if (products.isNotEmpty)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth < 290 ? 1 : 2;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: products.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 18,
                    mainAxisExtent: 286,
                  ),
                  itemBuilder: (context, index) => Entrance(
                    key: ValueKey(products[index].name),
                    child: ProductCard(
                      product: products[index],
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductDetailPage(product: products[index]),
                          ),
                        );
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                );
              },
            ),
          const SizedBox(height: 24),
          const Center(
            child: Text(
              'SNAPWEAR / MADE FOR YOUR EVERYDAY',
              style: TextStyle(
                fontSize: 9,
                letterSpacing: 1.5,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        backgroundColor: Colors.white,
        indicatorColor: lime,
        onDestinationSelected: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WishlistPage()),
            );
          }
          if (index == 2) {
            openCart();
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyOrdersPage()),
            );
          }
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            );
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view_rounded),
            label: 'Shop',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            label: 'Wishlist',
          ),
          NavigationDestination(icon: CartBadge(), label: 'Cart'),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class Entrance extends StatelessWidget {
  final Widget child;
  const Entrance({super.key, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 480),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (_, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: child,
        ),
      ),
    );
  }
}

// Illustrated placeholders, to be replaced with SnapWear product photographs.
class GarmentArt extends StatelessWidget {
  final Product product;
  const GarmentArt({super.key, required this.product});
  @override
  Widget build(BuildContext context) {
    final index = catalog.indexWhere((p) => p.name == product.name);
    const backgrounds = [
      Color(0xFFE5E8DD),
      Color(0xFFDEE4E9),
      Color(0xFFEBE3D9),
      Color(0xFFE7DFEA),
    ];
    const fabrics = [
      Color(0xFF566548),
      Color(0xFF536B83),
      Color(0xFFB19676),
      Color(0xFF746078),
    ];
    final i = index < 0 ? 0 : index;
    return Container(
      decoration: BoxDecoration(
        color: backgrounds[i],
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          Positioned(
            right: 12,
            top: 12,
            child: Text(
              '0${i + 1}',
              style: const TextStyle(fontSize: 10, color: Colors.black38),
            ),
          ),
          Center(
            child: FractionallySizedBox(
              widthFactor: .78,
              heightFactor: .8,
              child: CustomPaint(painter: GarmentPainter(fabrics[i], i)),
            ),
          ),
        ],
      ),
    );
  }
}

class GarmentPainter extends CustomPainter {
  final Color color;
  final int kind;
  GarmentPainter(this.color, this.kind);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 200, size.height / 220);
    final path = Path()
      ..moveTo(68, 35)
      ..lineTo(40, 48)
      ..lineTo(12, 91)
      ..lineTo(40, 108)
      ..lineTo(57, 83)
      ..lineTo(54, 190)
      ..quadraticBezierTo(100, 201, 146, 190)
      ..lineTo(143, 83)
      ..lineTo(160, 108)
      ..lineTo(188, 91)
      ..lineTo(160, 48)
      ..lineTo(132, 35)
      ..quadraticBezierTo(100, 59, 68, 35)
      ..close();
    canvas.drawShadow(path, Colors.black, 7, false);
    canvas.drawPath(path, Paint()..color = color);
    final seam = Paint()
      ..color = Colors.white.withValues(alpha: .35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawPath(
      Path()
        ..moveTo(68, 35)
        ..quadraticBezierTo(100, 76, 132, 35),
      seam,
    );
    canvas.drawLine(const Offset(62, 184), const Offset(138, 184), seam);
    if (kind == 1 || kind == 2) {
      canvas.drawLine(const Offset(100, 57), const Offset(100, 190), seam);
      canvas.drawRect(const Rect.fromLTWH(114, 78, 22, 24), seam);
      for (double y = 76; y < 180; y += 22) {
        canvas.drawCircle(Offset(100, y), 2, Paint()..color = cream);
      }
    }
    if (kind == 3) {
      canvas.drawPath(
        Path()
          ..moveTo(72, 39)
          ..quadraticBezierTo(65, 4, 100, 7)
          ..quadraticBezierTo(135, 4, 128, 39),
        seam,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(76, 133, 48, 30),
          const Radius.circular(6),
        ),
        seam,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(GarmentPainter old) =>
      old.color != color || old.kind != kind;
}

class ProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback onTap;
  const ProductCard({super.key, required this.product, required this.onTap});
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Hero(
                  tag: product.name,
                  child: GarmentArt(product: product),
                ),
                Positioned(
                  left: 8,
                  top: 8,
                  child: FavoriteButton(product: product),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '₹${product.price}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              const Icon(Icons.arrow_outward, size: 18),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class ProductDetailPage extends StatelessWidget {
  final Product product;
  const ProductDetailPage({super.key, required this.product});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('The collection'),
      actions: [
        FavoriteButton(product: product),
        IconButton(
          tooltip: 'Open cart',
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CartPage()),
          ),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SizedBox(
          height: 340,
          child: Hero(
            tag: product.name,
            child: GarmentArt(product: product),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'SNAPWEAR ESSENTIALS',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 2,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          product.name,
          style: TextStyle(
            fontFamily: 'SnapSerif',
            fontSize: 32,
            fontWeight: FontWeight.w700,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          '₹${product.price}',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 16),
        const Text(
          'An everyday essential.',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        const Text(
          'Build your daily rotation with this SnapWear style. '
          'Pair it with your favourite pieces and make the look your own.',
          style: TextStyle(height: 1.7, color: Colors.black54),
        ),
        const SizedBox(height: 24),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: ElevatedButton.icon(
          icon: const Icon(Icons.add_shopping_cart),
          label: const Text('ADD TO CART'),
          onPressed: () {
            Cart.add(product);
            ScaffoldMessenger.of(context).removeCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${product.name} added to your bag'),
                duration: const Duration(seconds: 2),
                showCloseIcon: true,
              ),
            );
          },
        ),
      ),
    ),
  );
}

// ---------------- PRODUCT MODEL ----------------

class Product {
  final String name;
  final int price;
  final IconData icon;

  const Product({required this.name, required this.price, required this.icon});
}
// ← Product ends here

// PASTE CART PAGE HERE
class Cart {
  static final List<Product> items = [];
  static final count = ValueNotifier<int>(0);

  static void add(Product product) {
    items.add(product);
    count.value = items.length;
  }

  static void removeOne(Product product) {
    final index = items.lastIndexWhere((item) => item.name == product.name);
    if (index >= 0) {
      items.removeAt(index);
      count.value = items.length;
    }
  }

  static void removeAll(Product product) {
    items.removeWhere((item) => item.name == product.name);
    count.value = items.length;
  }
}

class CartBadge extends StatelessWidget {
  const CartBadge({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: Cart.count,
    builder: (context, itemCount, _) => Badge(
      isLabelVisible: itemCount > 0,
      label: Text('$itemCount'),
      child: const Icon(Icons.shopping_bag_outlined),
    ),
  );
}

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  @override
  Widget build(BuildContext context) {
    // Create a list of unique products
    final Map<String, Product> uniqueProducts = {};

    for (final product in Cart.items) {
      uniqueProducts[product.name] = product;
    }

    final products = uniqueProducts.values.toList();

    return Scaffold(
      appBar: AppBar(title: Text('My Cart (${Cart.items.length})')),
      body: Cart.items.isEmpty
          ? const Center(child: Text('Your cart is empty'))
          : ListView.builder(
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];

                final quantity = Cart.items
                    .where((item) => item.name == product.name)
                    .length;

                return ListTile(
                  title: Text(product.name),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('₹${product.price} × $quantity'),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () {
                              setState(() {
                                Cart.removeOne(product);
                              });
                            },
                          ),

                          Text(
                            '$quantity',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              setState(() {
                                Cart.add(product);
                              });
                            },
                          ),

                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () {
                              setState(() {
                                Cart.removeAll(product);
                              });
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${Cart.items.length} ${Cart.items.length == 1 ? 'item' : 'items'}'
                  ' • ${products.length} ${products.length == 1 ? 'product' : 'products'}',
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Bag total',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '₹${Cart.items.fold<int>(0, (runningTotal, p) => runningTotal + p.price)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: Cart.items.isEmpty
                      ? null
                      : () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentPage(),
                          ),
                        ),
                  child: const Text('CHECKOUT  →'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PaymentPage extends StatefulWidget {
  const PaymentPage({super.key});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  String? selectedMethod;

  Widget paymentOption(String method, IconData icon, {String? subtitle}) {
    final isSelected = selectedMethod == method;

    return AnimatedContainer(
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 220),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? lime : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isSelected ? ink : const Color(0xFFE0E2D8)),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(method),
        subtitle: subtitle == null ? null : Text(subtitle),
        trailing: Icon(
          isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isSelected ? ink : Colors.grey,
        ),
        onTap: () {
          setState(() {
            selectedMethod = method;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text(
                    'Choose Payment Method',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 25),
                  paymentOption(
                    'UPI',
                    Icons.account_balance_wallet,
                    subtitle: 'Google Pay / PhonePe / Paytm',
                  ),
                  paymentOption('Credit / Debit Card', Icons.credit_card),
                  paymentOption('Net Banking', Icons.account_balance),
                ],
              ),
            ),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: selectedMethod == null
                    ? null
                    : () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderReviewPage(
                              paymentMethod: selectedMethod!,
                              items: List<Product>.from(Cart.items),
                            ),
                          ),
                        );
                      },
                child: const Text(
                  'PROCEED TO PAY',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OrderReviewPage extends StatefulWidget {
  final String paymentMethod;
  final List<Product> items;

  const OrderReviewPage({
    super.key,
    required this.paymentMethod,
    required this.items,
  });

  @override
  State<OrderReviewPage> createState() => _OrderReviewPageState();
}

class _OrderReviewPageState extends State<OrderReviewPage> {
  bool _demoCreated = false;
  bool _savingOrder = false;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final details = profileDetails.value;
    _nameController.text = details.name;
    _phoneController.text = details.phone;
    _addressController.text = details.address;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _reviewDetails() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.items.isEmpty || _demoCreated) return;
    FocusScope.of(context).unfocus();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delivery Details'),
        content: SingleChildScrollView(
          child: Text(
            'Name: ${_nameController.text.trim()}\n\n'
            'Phone: ${_phoneController.text.trim()}\n\n'
            'Address: ${_addressController.text.trim()}\n\n'
            'Payment method: ${widget.paymentMethod}\n\n'
            'Create a demo order to preview order history. '
            'No real order is sent and no payment is charged.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('EDIT'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (_demoCreated || _savingOrder) return;
              setState(() => _savingOrder = true);
              final order = DemoOrder(
                id: 'DEMO-${DateTime.now().microsecondsSinceEpoch}',
                createdAt: DateTime.now(),
                items: List<Product>.unmodifiable(widget.items),
                paymentMethod: widget.paymentMethod,
                name: _nameController.text.trim(),
                phone: _phoneController.text.trim(),
                address: _addressController.text.trim(),
              );
              try {
                await AccountStorage.saveOrder(order);
              } catch (_) {
                if (!mounted || !dialogContext.mounted) return;
                setState(() => _savingOrder = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Could not save the demo order. Check your connection and retry.',
                    ),
                  ),
                );
                return;
              }
              if (!mounted || !dialogContext.mounted) return;
              demoOrders.value = [order, ...demoOrders.value];
              setState(() => _demoCreated = true);
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyOrdersPage()),
              );
            },
            child: const Text('CREATE DEMO ORDER'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, Product> products = {};
    final Map<String, int> quantities = {};

    for (final item in widget.items) {
      products[item.name] = item;
      quantities[item.name] = (quantities[item.name] ?? 0) + 1;
    }

    final total = widget.items.fold<int>(
      0,
      (runningTotal, item) => runningTotal + item.price,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Order Review')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Your Order',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (widget.items.isEmpty) const Text('Your cart is empty'),
            ...products.values.map((product) {
              final quantity = quantities[product.name]!;

              return Card(
                child: ListTile(
                  leading: Icon(product.icon),
                  title: Text(product.name),
                  subtitle: Text('₹${product.price} × $quantity'),
                  trailing: Text('₹${product.price * quantity}'),
                ),
              );
            }),
            const Divider(),
            Text(
              'Payment method: ${widget.paymentMethod}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  '₹$total',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            const Text(
              'Delivery Details',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Mobile Number',
                hintText: '10-digit Indian mobile number',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final phone = (value ?? '').trim();
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(phone)) {
                  return 'Enter a valid 10-digit mobile number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            DeliveryAddressFields(controller: _addressController),
            const SizedBox(height: 24),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: widget.items.isEmpty || _demoCreated
                    ? null
                    : _reviewDetails,
                child: const Text(
                  'REVIEW DELIVERY DETAILS',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Demo orders are saved to your account when signed in. No payment is charged.',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

// Account form preview. Connect an authentication service before launch.
class AccountPage extends StatefulWidget {
  final bool startup;
  const AccountPage({super.key, this.startup = false});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final formKey = GlobalKey<FormState>();
  final name = TextEditingController();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirmation = TextEditingController();
  bool busy = false;
  String? authError;
  bool signUp = false;
  bool hidden = true;

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  void complete() {
    if (widget.startup) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          transitionDuration: const Duration(milliseconds: 420),
          pageBuilder: (_, _, _) => const HomePage(),
          transitionsBuilder: (_, animation, _, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: child,
          ),
        ),
      );
    } else {
      Navigator.pop(context);
    }
  }

  void switchMode() {
    if (busy) return;
    formKey.currentState?.reset();
    password.clear();
    confirmation.clear();
    setState(() {
      authError = null;
      signUp = !signUp;
      hidden = true;
    });
  }

  String errorMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email already has an account. Try logging in.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Choose a stronger password with at least 8 characters.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled in Firebase.';
      case 'user-disabled':
        return 'This account is disabled.';
      default:
        return 'Could not complete sign-in (${error.code}). Please try again.';
    }
  }

  Future<void> submit() async {
    if (busy || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      authError = null;
    });
    try {
      if (signUp) {
        final result = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(
              email: email.text.trim(),
              password: password.text,
            );
        try {
          await result.user!.updateDisplayName(name.text.trim());
          final current = profileDetails.value;
          profileDetails.value = ProfileDetails(
            name: name.text.trim(),
            email: result.user!.email ?? '',
            phone: current.phone,
            address: current.address,
          );
        } catch (_) {
          // Account creation succeeded; display name can be edited later.
        }
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email.text.trim(),
          password: password.text,
        );
      }
      if (!mounted) return;
      password.clear();
      confirmation.clear();
      complete();
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => authError = errorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => authError = 'Could not connect. Please try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resetPassword() async {
    if (busy) return;
    final value = email.text.trim();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
      setState(
        () => authError = 'Enter your email above, then tap Forgot password.',
      );
      return;
    }
    setState(() {
      busy = true;
      authError = null;
    });
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'If an account exists for that email, a reset link will arrive.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (mounted) setState(() => authError = errorMessage(error));
    } catch (_) {
      if (mounted) {
        setState(() => authError = 'Could not send the reset link. Try again.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.startup,
      actions: [
        TextButton(
          onPressed: busy ? null : complete,
          child: const Text('Skip'),
        ),
      ],
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Form(
            key: formKey,
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const SizedBox(height: 8),
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      const Icon(
                        Icons.shopping_bag_rounded,
                        size: 86,
                        color: royalInk,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 15),
                        child: Text(
                          'S',
                          style: const TextStyle(
                            fontFamily: 'SnapSerif',
                            fontSize: 46,
                            color: royalCream,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: RoyalWordmark()),
                const SizedBox(height: 8),
                const Text(
                  'Fashion near you. Delivered beautifully.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: royalGold, fontSize: 12),
                ),
                const SizedBox(height: 28),
                Text(
                  signUp ? 'Create your account' : 'Welcome back',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'SnapSerif',
                    fontSize: 34,
                    color: royalInk,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E7D8),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      for (final mode in [false, true])
                        Expanded(
                          child: TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: signUp == mode
                                  ? royalInk
                                  : Colors.transparent,
                              foregroundColor: signUp == mode
                                  ? royalCream
                                  : royalInk,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: busy
                                ? null
                                : () {
                                    if (signUp != mode) switchMode();
                                  },
                            child: Text(mode ? 'Sign Up' : 'Log In'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 26),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email address',
                    prefixIcon: Icon(Icons.mail_outline),
                  ),
                  validator: (value) =>
                      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                          .hasMatch((value ?? '').trim())
                      ? null
                      : 'Enter a valid email address',
                ),
                const SizedBox(height: 16),
                if (signUp) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Full name',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                        (value ?? '').trim().isEmpty ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                TextFormField(
                  controller: password,
                  obscureText: hidden,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: signUp
                      ? TextInputAction.next
                      : TextInputAction.done,
                  onFieldSubmitted: (_) {
                    if (!signUp) submit();
                  },
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      tooltip: hidden ? 'Show password' : 'Hide password',
                      onPressed: () => setState(() => hidden = !hidden),
                      icon: Icon(
                        hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if ((value ?? '').isEmpty) return 'Enter a password';
                    if (signUp && value!.length < 8) {
                      return 'Use at least 8 characters';
                    }
                    return null;
                  },
                ),
                if (signUp) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmation,
                    obscureText: hidden,
                    autocorrect: false,
                    enableSuggestions: false,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => submit(),
                    decoration: const InputDecoration(
                      labelText: 'Confirm password',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    validator: (value) => (value ?? '').isEmpty
                        ? 'Confirm your password'
                        : value != password.text
                        ? 'Passwords do not match'
                        : null,
                  ),
                ],
                const SizedBox(height: 24),
                if (authError != null) ...[
                  Text(
                    authError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                ElevatedButton(
                  onPressed: busy ? null : submit,
                  child: Text(
                    busy
                        ? 'PLEASE WAIT…'
                        : signUp
                        ? 'CREATE ACCOUNT  →'
                        : 'LOG IN  →',
                  ),
                ),
                GoogleLoginButton(
                  onSuccess: () {
                    if (mounted) complete();
                  },
                ),
                if (!signUp)
                  TextButton(
                    onPressed: busy ? null : resetPassword,
                    child: const Text('Forgot password?'),
                  ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: busy ? null : switchMode,
                  child: Text(
                    signUp
                        ? 'Already have an account? Log in'
                        : 'New to SnapWear? Sign up',
                  ),
                ),
                TextButton(
                  onPressed: busy ? null : complete,
                  child: const Text('Continue shopping as a guest'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Your local style, all in one place.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class FavoriteButton extends StatelessWidget {
  final Product product;
  const FavoriteButton({super.key, required this.product});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<List<Product>>(
    valueListenable: savedProducts,
    builder: (context, products, _) {
      final saved = products.any((p) => p.name == product.name);
      return IconButton(
        tooltip: saved ? 'Remove from wishlist' : 'Save to wishlist',
        style: IconButton.styleFrom(
          backgroundColor: saved ? lime : Colors.white,
        ),
        icon: AnimatedSwitcher(
          duration: MediaQuery.of(context).disableAnimations
              ? Duration.zero
              : const Duration(milliseconds: 180),
          child: Icon(
            saved ? Icons.favorite : Icons.favorite_border,
            key: ValueKey(saved),
            color: ink,
          ),
        ),
        onPressed: () {
          savedProducts.value = saved
              ? products.where((p) => p.name != product.name).toList()
              : [...products, product];
        },
      );
    },
  );
}

class WishlistPage extends StatelessWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your wishlist')),
    body: ValueListenableBuilder<List<Product>>(
      valueListenable: savedProducts,
      builder: (context, products, _) {
        if (products.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_border, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Save your next look.',
                    style: TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tap a heart on a product to keep it here.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('EXPLORE THE COLLECTION'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              '${products.length} saved pieces',
              style: TextStyle(
                fontFamily: 'SnapSerif',
                fontSize: 26,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            ...products.map(
              (product) => Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 72,
                            height: 86,
                            child: GarmentArt(product: product),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text('₹${product.price}'),
                              ],
                            ),
                          ),
                          FavoriteButton(product: product),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductDetailPage(product: product),
                                ),
                              ),
                              child: const Text('VIEW'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                Cart.add(product);
                                ScaffoldMessenger.of(context)
                                    .removeCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    duration: const Duration(seconds: 2),
                                    showCloseIcon: true,
                                    content: Text(
                                      '${product.name} added to your bag',
                                    ),
                                  ),
                                );
                              },
                              child: const Text('ADD TO CART'),
                            ),
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

const demoStages = [
  'Placed',
  'Confirmed',
  'Packed',
  'Out for delivery',
  'Delivered',
];

class DemoOrder {
  final String id;
  final DateTime createdAt;
  final List<Product> items;
  final String paymentMethod;
  final String name;
  final String phone;
  final String address;
  final int demoStage;

  const DemoOrder({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.paymentMethod,
    required this.name,
    required this.phone,
    required this.address,
    this.demoStage = 0,
  });

  DemoOrder atStage(int value) => DemoOrder(
    id: id,
    createdAt: createdAt,
    items: items,
    paymentMethod: paymentMethod,
    name: name,
    phone: phone,
    address: address,
    demoStage: value,
  );

  int get total =>
      items.fold<int>(0, (runningTotal, item) => runningTotal + item.price);
}

class MyOrdersPage extends StatelessWidget {
  const MyOrdersPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My Orders')),
    body: ValueListenableBuilder<List<DemoOrder>>(
      valueListenable: demoOrders,
      builder: (context, orders, _) {
        if (orders.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 56),
                  const SizedBox(height: 20),
                  Text(
                    'Your story starts here.',
                    style: TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No orders yet. Create a demo order through checkout '
                    'to preview your order history.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () =>
                        Navigator.popUntil(context, (route) => route.isFirst),
                    child: const Text('BACK TO SHOP'),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Demo orders • no payment charged',
              style: TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ...orders.map(
              (order) => Card(
                color: Colors.white,
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: lime,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'DEMO / UNPAID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Demo stage: ${demoStages[order.demoStage]}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        order.id,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${order.createdAt.day}/${order.createdAt.month}/${order.createdAt.year} '
                        '• ${order.items.length} items',
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '₹${order.total}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => OrderDetailsPage(order: order),
                          ),
                        ),
                        child: const Text('VIEW DETAILS'),
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

class OrderDetailsPage extends StatefulWidget {
  final DemoOrder order;
  const OrderDetailsPage({super.key, required this.order});
  @override
  State<OrderDetailsPage> createState() => _OrderDetailsPageState();
}

class _OrderDetailsPageState extends State<OrderDetailsPage> {
  late DemoOrder order;
  bool advancing = false;
  @override
  void initState() {
    super.initState();
    order = widget.order;
  }

  Future<void> advanceDemo() async {
    if (advancing || order.demoStage >= demoStages.length - 1) return;
    setState(() => advancing = true);
    final next = order.atStage(order.demoStage + 1);
    try {
      await AccountStorage.saveOrder(next);
      if (!mounted) return;
      demoOrders.value = demoOrders.value
          .map((item) => item.id == next.id ? next : item)
          .toList();
      setState(() => order = next);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not save the demo stage. Please retry.'),
        ),
      );
    } finally {
      if (mounted) setState(() => advancing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final products = <String, Product>{};
    final quantities = <String, int>{};
    for (final item in order.items) {
      products[item.name] = item;
      quantities[item.name] = (quantities[item.name] ?? 0) + 1;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Order Details')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(order.id, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text(
            'Demo order • unpaid • not sent for delivery',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Track your order',
                    style: TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Demo simulation • no real delivery is happening',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  for (int i = 0; i < demoStages.length; i++) ...[
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: MediaQuery.of(context).disableAnimations
                              ? Duration.zero
                              : const Duration(milliseconds: 220),
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: i <= order.demoStage ? lime : cream,
                          ),
                          child: Icon(
                            i < order.demoStage
                                ? Icons.check
                                : i == order.demoStage
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            size: 20,
                            color: i <= order.demoStage ? ink : Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            demoStages[i],
                            style: TextStyle(
                              fontWeight: i == order.demoStage
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i <= order.demoStage ? ink : Colors.grey,
                            ),
                          ),
                        ),
                        if (i == order.demoStage)
                          const Text(
                            'DEMO',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                      ],
                    ),
                    if (i < demoStages.length - 1)
                      Padding(
                        padding: const EdgeInsets.only(left: 18),
                        child: Container(
                          width: 2,
                          height: 18,
                          color: i < order.demoStage ? ink : Colors.black12,
                        ),
                      ),
                  ],
                  const SizedBox(height: 24),
                  if (order.demoStage < demoStages.length - 1)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: advancing ? null : advanceDemo,
                        child: Text(
                          advancing ? 'SAVING…' : 'SIMULATE NEXT STATUS',
                        ),
                      ),
                    )
                  else
                    const Text(
                      'Demo completed. No real order was delivered.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          ...products.values.map(
            (product) => Card(
              color: Colors.white,
              child: ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '₹${product.price} × ${quantities[product.name]}',
                ),
                trailing: Text('₹${product.price * quantities[product.name]!}'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Total: ₹${order.total}',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Text('Payment method: ${order.paymentMethod}'),
          const Divider(height: 36),
          const Text(
            'Delivery Details',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            '${order.name}\n${order.phone}\n${order.address}',
            style: const TextStyle(height: 1.7),
          ),
        ],
      ),
    );
  }
}

class ProfileDetails {
  final String name;
  final String email;
  final String phone;
  final String address;
  const ProfileDetails({
    this.name = '',
    this.email = '',
    this.phone = '',
    this.address = '',
  });
}

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) => const CustomerAccountHub();
}

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final formKey = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController email;
  late final TextEditingController phone;
  late final TextEditingController address;

  @override
  void initState() {
    super.initState();
    final details = profileDetails.value;
    name = TextEditingController(text: details.name);
    email = TextEditingController(text: details.email);
    phone = TextEditingController(text: details.phone);
    address = TextEditingController(text: details.address);
  }

  @override
  void dispose() {
    name.dispose();
    email.dispose();
    phone.dispose();
    address.dispose();
    super.dispose();
  }

  bool saving = false;
  Future<void> save() async {
    if (saving || !formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => saving = true);
    final details = ProfileDetails(
      name: name.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      address: address.text.trim(),
    );
    try {
      await AccountStorage.saveProfile(details);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Profile could not be saved. Check your connection and retry.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Edit Profile')),
    body: SafeArea(
      child: Form(
        key: formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Your everyday details.',
              style: TextStyle(
                fontFamily: 'SnapSerif',
                fontSize: 28,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Use sample details while testing.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter your name' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Contact email (does not change login)',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (value) =>
                  RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                      .hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter a valid email',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Mobile number',
                hintText: '10-digit Indian mobile number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (value) =>
                  RegExp(r'^[6-9]\d{9}$').hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter a valid 10-digit mobile number',
            ),
            const SizedBox(height: 16),
            DeliveryAddressFields(controller: address),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: saving ? null : save,
              child: Text(saving ? 'SAVING…' : 'SAVE PROFILE  →'),
            ),
          ],
        ),
      ),
    ),
  );
}

class DeliveryAddressFields extends StatefulWidget {
  final TextEditingController controller;
  const DeliveryAddressFields({super.key, required this.controller});
  @override
  State<DeliveryAddressFields> createState() => _DeliveryAddressFieldsState();
}

class _DeliveryAddressFieldsState extends State<DeliveryAddressFields> {
  static const labels = [
    'House / Street',
    'Area',
    'Landmark',
    'City',
    'State',
    'PIN code',
  ];
  late final List<TextEditingController> fields;

  @override
  void initState() {
    super.initState();
    final initial = <String, String>{};
    for (final line in widget.controller.text.split('\n')) {
      final separator = line.indexOf(': ');
      if (separator >= 0) {
        initial[line.substring(0, separator)] = line.substring(separator + 2);
      }
    }
    fields = labels
        .map((label) => TextEditingController(text: initial[label] ?? ''))
        .toList();
    // Keep an older free-form address available for the customer to edit.
    if (initial.isEmpty && widget.controller.text.isNotEmpty) {
      fields[0].text = widget.controller.text.replaceAll('\n', ', ');
    }
  }

  void updateAddress() {
    widget.controller.text = [
      for (int i = 0; i < labels.length; i++)
        if (fields[i].text.trim().isNotEmpty)
          '${labels[i]}: ${fields[i].text.trim()}',
    ].join('\n');
  }

  @override
  void dispose() {
    for (final field in fields) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Delivery address',
        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text(
        'Enter the address where you want your order delivered.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      ),
      const SizedBox(height: 16),
      for (int i = 0; i < labels.length; i++) ...[
        TextFormField(
          controller: fields[i],
          keyboardType: i == 5
              ? TextInputType.number
              : TextInputType.streetAddress,
          textCapitalization: i == 5
              ? TextCapitalization.none
              : TextCapitalization.words,
          textInputAction: i == 5 ? TextInputAction.done : TextInputAction.next,
          decoration: InputDecoration(
            labelText: i == 2 ? 'Landmark (optional)' : '${labels[i]} *',
            hintText: i == 0
                ? 'Flat / house number and street'
                : i == 5
                ? '6-digit Indian PIN code'
                : null,
          ),
          onChanged: (_) => updateAddress(),
          validator: (value) {
            final text = (value ?? '').trim();
            if (i == 2) return null;
            if (text.isEmpty) return 'Enter ${labels[i].toLowerCase()}';
            if (i == 5 && !RegExp(r'^[1-9]\d{5}$').hasMatch(text)) {
              return 'Enter a valid 6-digit PIN code';
            }
            return null;
          },
        ),
        if (i < labels.length - 1) const SizedBox(height: 16),
      ],
    ],
  );
}

// Account-scoped storage. Product names are temporary catalog identifiers.
class AccountStorage {
  static final loading = ValueNotifier<bool>(false);
  static final error = ValueNotifier<String?>(null);
  static final saving = ValueNotifier<bool>(false);
  static String? uid;
  static bool ready = false;
  static bool applying = false;
  static bool deleting = false;
  static int generation = 0;
  static Future<void> tail = Future<void>.value();

  static void start() {
    Cart.count.addListener(scheduleSave);
    savedProducts.addListener(scheduleSave);
    FirebaseAuth.instance.userChanges().listen((user) {
      if (uid != user?.uid || !ready) {
        unawaited(loadUser(user));
      } else if (user != null && profileDetails.value.name.isEmpty) {
        final old = profileDetails.value;
        profileDetails.value = ProfileDetails(
          name: user.displayName ?? '',
          email: old.email,
          phone: old.phone,
          address: old.address,
        );
      }
    });
  }

  static List<Product> decodeProducts(dynamic names) {
    if (names is! List) return [];
    final result = <Product>[];
    for (final name in names) {
      for (final product in catalog) {
        if (product.name == name) {
          result.add(product);
          break;
        }
      }
    }
    return result;
  }

  static Future<void> loadUser(User? user) async {
    final token = ++generation;
    uid = user?.uid;
    ready = false;
    loading.value = true;
    error.value = null;
    applying = true;
    profileDetails.value = ProfileDetails(
      name: user?.displayName ?? '',
      email: user?.email ?? '',
    );
    Cart.items.clear();
    Cart.count.value = 0;
    savedProducts.value = [];
    demoOrders.value = [];
    applying = false;
    if (user == null) {
      ready = true;
      loading.value = false;
      return;
    }
    try {
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      final document = await reference
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      final orders = await reference
          .collection('demoOrders')
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));
      if (token != generation) return;
      final data = document.data() ?? <String, dynamic>{};
      applying = true;
      profileDetails.value = ProfileDetails(
        name: data['name'] as String? ?? user.displayName ?? '',
        email: data['email'] as String? ?? user.email ?? '',
        phone: data['phone'] as String? ?? '',
        address: data['address'] as String? ?? '',
      );
      Cart.items.addAll(decodeProducts(data['cart']));
      Cart.count.value = Cart.items.length;
      savedProducts.value = decodeProducts(data['wishlist']);
      demoOrders.value = orders.docs.map((doc) {
        final data = doc.data();
        return DemoOrder(
          id: doc.id,
          createdAt: (data['createdAt'] as Timestamp).toDate(),
          items: List<Product>.unmodifiable(decodeProducts(data['items'])),
          paymentMethod: data['paymentMethod'] as String,
          name: data['name'] as String,
          phone: data['phone'] as String,
          address: data['address'] as String,
          demoStage: ((data['demoStage'] as num?)?.toInt() ?? 0)
              .clamp(0, demoStages.length - 1)
              .toInt(),
        );
      }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      applying = false;
      ready = true;
    } catch (_) {
      if (token == generation) {
        applying = false;
        error.value =
            'Could not load your saved data. Check your connection '
            'and published Firestore rules, then retry.';
      }
    } finally {
      if (token == generation) loading.value = false;
    }
  }

  static Map<String, dynamic> snapshot(ProfileDetails details) => {
    'name': details.name,
    'email': details.email,
    'phone': details.phone,
    'address': details.address,
    'cart': Cart.items.map((p) => p.name).toList(),
    'wishlist': savedProducts.value.map((p) => p.name).toList(),
    'updatedAt': FieldValue.serverTimestamp(),
  };

  static Future<void> write(Map<String, dynamic> data) {
    final owner = uid;
    final token = generation;
    if (owner == null) return Future<void>.value();
    if (!ready) {
      return Future<void>.error(StateError('Account data is not loaded'));
    }
    saving.value = true;
    final operation = tail.catchError((Object _) {}).then((_) async {
      if (token != generation ||
          owner != FirebaseAuth.instance.currentUser?.uid) {
        throw StateError('Account changed');
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(owner)
          .set(data, SetOptions(merge: true));
    });
    tail = operation;
    unawaited(
      operation.then(
        (_) {
          if (token == generation && identical(tail, operation)) {
            saving.value = false;
            error.value = null;
          }
        },
        onError: (Object _) {
          if (token == generation) {
            saving.value = false;
            error.value =
                'Changes could not be saved. Check your connection and retry.';
          }
        },
      ),
    );
    return operation;
  }

  static void scheduleSave() {
    if (applying || deleting || !ready || uid == null) return;
    unawaited(write(snapshot(profileDetails.value)).catchError((Object _) {}));
  }

  static Future<void> saveProfile(ProfileDetails details) async {
    await write(snapshot(details));
    profileDetails.value = details;
  }

  static Future<void> saveOrder(DemoOrder order) async {
    final owner = uid;
    final token = generation;
    if (owner == null) return;
    if (!ready || deleting) throw StateError('Account data is not ready');
    await FirebaseFirestore.instance
        .collection('users')
        .doc(owner)
        .collection('demoOrders')
        .doc(order.id)
        .set({
          'createdAt': Timestamp.fromDate(order.createdAt),
          'items': order.items.map((p) => p.name).toList(),
          'paymentMethod': order.paymentMethod,
          'name': order.name,
          'phone': order.phone,
          'address': order.address,
          'status': 'demo',
          'paymentStatus': 'unpaid',
          'demoStage': order.demoStage,
        });
    if (token != generation) throw StateError('Account changed');
  }

  static Future<void> flush() async {
    if (uid != null) await write(snapshot(profileDetails.value));
    await tail;
  }

  static Future<void> retry() async {
    if (!ready) {
      await loadUser(FirebaseAuth.instance.currentUser);
    } else {
      try {
        await flush();
      } catch (_) {}
    }
  }
}

class StorageFeedback extends StatelessWidget {
  final Widget child;
  const StorageFeedback({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: AccountStorage.loading,
    builder: (context, loading, _) => ValueListenableBuilder<String?>(
      valueListenable: AccountStorage.error,
      builder: (context, error, _) => Column(
        children: [
          if (error != null)
            Material(
              color: lime,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          error,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      TextButton(
                        onPressed: () => AccountStorage.retry(),
                        child: const Text('RETRY'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                child,
                if (loading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0xDDFFF7EC),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
                if (!loading)
                  Positioned(
                    right: 12,
                    top: 4,
                    child: ValueListenableBuilder<bool>(
                      valueListenable: AccountStorage.saving,
                      builder: (_, saving, _) => saving
                          ? const Material(
                              color: cream,
                              child: Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  'Saving…',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class DemoStore {
  final String id;
  final String name;
  final String brand;
  final String area;
  final latlong.LatLng point;
  final List<String> products;
  const DemoStore({
    required this.id,
    required this.name,
    required this.brand,
    required this.area,
    required this.point,
    required this.products,
  });
}

const sampleStores = <DemoStore>[
  DemoStore(
    id: 'demo-1',
    name: 'SnapWear Studio',
    brand: 'SnapWear',
    area: 'T. Nagar, Chennai',
    point: latlong.LatLng(13.0418, 80.2341),
    products: ['Classic T-Shirt', 'Casual Shirt'],
  ),
  DemoStore(
    id: 'demo-2',
    name: 'Thread House',
    brand: 'Thread House',
    area: 'Anna Nagar, Chennai',
    point: latlong.LatLng(13.0850, 80.2101),
    products: ['Denim Jacket', 'Hoodie'],
  ),
  DemoStore(
    id: 'demo-3',
    name: 'Daily Edit',
    brand: 'Daily Edit',
    area: 'Mylapore, Chennai',
    point: latlong.LatLng(13.0336, 80.2699),
    products: ['Classic T-Shirt', 'Hoodie'],
  ),
];

class StoreDiscoveryPage extends StatefulWidget {
  const StoreDiscoveryPage({super.key});
  @override
  State<StoreDiscoveryPage> createState() => _StoreDiscoveryPageState();
}

class _StoreDiscoveryPageState extends State<StoreDiscoveryPage> {
  final search = TextEditingController();
  final mapController = MapController();
  latlong.LatLng area = const latlong.LatLng(13.055, 80.235);
  latlong.LatLng? deviceLocation;
  String areaLabel = 'Demo area: Chennai';
  String? locationError;
  String? selectedId;
  bool locating = false;
  bool mapReady = false;

  @override
  void dispose() {
    search.dispose();
    mapController.dispose();
    super.dispose();
  }

  double kilometers(DemoStore store) =>
      Geolocator.distanceBetween(
        area.latitude,
        area.longitude,
        store.point.latitude,
        store.point.longitude,
      ) /
      1000;

  List<DemoStore> get results {
    final query = search.text.trim().toLowerCase();
    return sampleStores
        .where(
          (store) =>
              kilometers(store) <= 10 &&
              '${store.name} ${store.brand} ${store.area}'
                  .toLowerCase()
                  .contains(query),
        )
        .toList()
      ..sort((a, b) => kilometers(a).compareTo(kilometers(b)));
  }

  void moveTo(latlong.LatLng point) {
    if (mapReady) mapController.move(point, 13);
  }

  void showDemoArea() {
    setState(() {
      area = const latlong.LatLng(13.055, 80.235);
      areaLabel = 'Demo area: Chennai';
      search.clear();
      selectedId = null;
      locationError = null;
    });
    moveTo(area);
  }

  Future<void> locate() async {
    if (locating) return;
    setState(() {
      locating = true;
      locationError = null;
    });
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError(
          'Turn on location services, or select an area on the map.',
        );
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError(
          'Location permission was denied. You can still select an area on the map.',
        );
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      if (!mounted) return;
      final point = latlong.LatLng(position.latitude, position.longitude);
      setState(() {
        area = point;
        deviceLocation = point;
        areaLabel = 'Near your current location';
        selectedId = null;
      });
      moveTo(point);
    } on StateError catch (error) {
      if (mounted) setState(() => locationError = error.message.toString());
    } catch (_) {
      if (mounted) {
        setState(
          () => locationError = 'Could not get your location. Check location permission or tap the map to choose an area.',
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  void selectStore(DemoStore store) {
    setState(() => selectedId = store.id);
    moveTo(store.point);
  }

  @override
  Widget build(BuildContext context) {
    final stores = results;
    return Scaffold(
      appBar: AppBar(title: const Text('Discover stores')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Find your next stop.',
            style: TextStyle(
              fontFamily: 'SnapSerif',
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sample stores only • not real retailers or brand partnerships',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 18),
          TextField(
            controller: search,
            onChanged: (_) => setState(() {}),
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            decoration: InputDecoration(
              hintText: 'Search store, brand or demo area',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: search.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        search.clear();
                        setState(() {});
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: locating ? null : locate,
                icon: const Icon(Icons.my_location),
                label: Text(locating ? 'LOCATING…' : 'CURRENT LOCATION'),
              ),
              TextButton(
                onPressed: showDemoArea,
                child: const Text('DEMO AREA'),
              ),
            ],
          ),
          if (locationError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                locationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            '$areaLabel • within 10 km',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap the map to choose a search area.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 300,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: FlutterMap(
                mapController: mapController,
                options: MapOptions(
                  initialCenter: area,
                  initialZoom: 12,
                  minZoom: 3,
                  maxZoom: 18,
                  onMapReady: () => mapReady = true,
                  onTap: (_, point) => setState(() {
                    area = point;
                    areaLabel = 'Selected map area';
                    selectedId = null;
                  }),
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.snapwear.customer',
                    maxNativeZoom: 19,
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: area,
                        width: 28,
                        height: 28,
                        child: const Icon(
                          Icons.adjust,
                          color: Colors.blue,
                          size: 26,
                        ),
                      ),
                      if (deviceLocation != null)
                        Marker(
                          point: deviceLocation!,
                          width: 22,
                          height: 22,
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 20,
                          ),
                        ),
                      ...stores.map(
                        (store) => Marker(
                          point: store.point,
                          width: 48,
                          height: 48,
                          child: IconButton(
                            tooltip: '${store.name} (demo)',
                            onPressed: () => selectStore(store),
                            icon: Icon(
                              Icons.location_on,
                              color: selectedId == store.id
                                  ? Colors.deepOrange
                                  : ink,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        '© OpenStreetMap contributors',
                        onTap: () => launchUrl(
                          Uri.parse('https://www.openstreetmap.org/copyright'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '${stores.length} matching demo stores',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (stores.isEmpty)
            Card(
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Text(
                      'No matching sample stores in this area.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Real retailer locations will be added later.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                    TextButton(
                      onPressed: showDemoArea,
                      child: const Text('SHOW CHENNAI DEMO STORES'),
                    ),
                  ],
                ),
              ),
            ),
          ...stores.map(
            (store) => Card(
              color: selectedId == store.id ? lime : Colors.white,
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${store.name} • DEMO',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('${store.brand} / ${store.area}'),
                    const SizedBox(height: 8),
                    Text(
                      '${kilometers(store).toStringAsFixed(1)} km straight-line distance',
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => selectStore(store),
                          child: const Text('SHOW PIN'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DemoStorePage(store: store),
                            ),
                          ),
                          child: const Text('VIEW STORE'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DemoStorePage extends StatelessWidget {
  final DemoStore store;
  const DemoStorePage({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final products = catalog
        .where((p) => store.products.contains(p.name))
        .toList();
    return Scaffold(
      appBar: AppBar(title: Text(store.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            store.brand,
            style: TextStyle(
              fontFamily: 'SnapSerif',
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(store.area),
          const SizedBox(height: 12),
          const Text(
            'Demo storefront with sample products. No real store order is placed.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: constraints.maxWidth < 290 ? 1 : 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 16,
                mainAxisExtent: 286,
              ),
              itemBuilder: (context, index) => ProductCard(
                product: products[index],
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductDetailPage(product: products[index]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class EmailVerificationCard extends StatefulWidget {
  const EmailVerificationCard({super.key});
  @override
  State<EmailVerificationCard> createState() => _EmailVerificationCardState();
}

class _EmailVerificationCardState extends State<EmailVerificationCard> {
  bool busy = false;
  int secondsLeft = 0;
  String? feedback;
  Timer? cooldown;

  @override
  void dispose() {
    cooldown?.cancel();
    super.dispose();
  }

  Future<void> sendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (busy || secondsLeft > 0 || user == null || user.emailVerified) return;
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      setState(() {
        secondsLeft = 60;
        feedback = 'Verification email sent. Check your inbox and spam folder.';
      });
      cooldown?.cancel();
      cooldown = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() => secondsLeft--);
        if (secondsLeft <= 0) timer.cancel();
      });
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(
        () => feedback = error.code == 'too-many-requests'
            ? 'Please wait a few minutes before requesting another email.'
            : 'Could not send the email. Check your connection and retry.',
      );
    } catch (_) {
      if (mounted) {
        setState(() => feedback = 'Could not send the email. Please retry.');
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> checkVerification() async {
    if (busy) return;
    setState(() {
      busy = true;
      feedback = null;
    });
    try {
      await FirebaseAuth.instance.currentUser?.reload();
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && user.emailVerified) {
        await user.getIdToken(true);
      }
      if (!mounted) return;
      setState(
        () =>
            feedback = user?.emailVerified == true ? 'Your email is verified.' : 'Not verified yet. Open the link in your email, then check again.',
      );
    } catch (_) {
      if (mounted) {
        setState(
          () => feedback = 'Could not check verification. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<User?>(
    stream: FirebaseAuth.instance.userChanges(),
    initialData: FirebaseAuth.instance.currentUser,
    builder: (context, snapshot) {
      final user = snapshot.data;
      if (user == null) return const SizedBox.shrink();
      final verified = user.emailVerified;
      return Card(
        color: verified ? lime : Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    verified
                        ? Icons.verified_outlined
                        : Icons.mark_email_unread_outlined,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      verified ? 'Email verified' : 'Verify your email',
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(user.email ?? ''),
              if (!verified) ...[
                const SizedBox(height: 10),
                const Text(
                  'Confirm that this email belongs to you by opening the verification link.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: busy || secondsLeft > 0
                          ? null
                          : sendVerification,
                      child: Text(
                        secondsLeft > 0
                            ? 'RESEND IN ${secondsLeft}s'
                            : 'SEND EMAIL',
                      ),
                    ),
                    OutlinedButton(
                      onPressed: busy ? null : checkVerification,
                      child: const Text('CHECK VERIFICATION'),
                    ),
                  ],
                ),
              ],
              if (feedback != null) ...[
                const SizedBox(height: 12),
                Text(feedback!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        ),
      );
    },
  );
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});
  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final password = TextEditingController();
  final confirmation = TextEditingController();
  final formKey = GlobalKey<FormState>();
  bool busy = false;
  String? error;

  @override
  void dispose() {
    password.dispose();
    confirmation.dispose();
    super.dispose();
  }

  Future<void> deleteAccount() async {
    if (busy || !formKey.currentState!.validate()) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permanently delete your account?'),
        content: const Text(
          'Your login, saved profile, address, cart, wishlist, '
          'and demo orders will be deleted. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('KEEP ACCOUNT'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('DELETE PERMANENTLY'),
          ),
        ],
      ),
    );
    if (!mounted || approved != true) return;
    setState(() {
      busy = true;
      error = null;
    });
    bool cleanupStarted = false;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        throw StateError('Please sign in again before deleting your account.');
      }
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(
          email: user.email!,
          password: password.text,
        ),
      );
      password.clear();
      if (AccountStorage.ready) await AccountStorage.flush();
      AccountStorage.deleting = true;
      await AccountStorage.tail.catchError((Object _) {});
      final reference = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid);
      cleanupStarted = true;
      // Firestore does not delete subcollections when deleting a parent document.
      while (true) {
        final documents = await reference
            .collection('demoOrders')
            .limit(400)
            .get(const GetOptions(source: Source.server));
        if (documents.docs.isEmpty) break;
        final batch = FirebaseFirestore.instance.batch();
        for (final document in documents.docs) {
          batch.delete(document.reference);
        }
        await batch.commit();
      }
      await reference.delete();
      await user.delete();
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } on FirebaseAuthException catch (exception) {
      if (!mounted) return;
      setState(
        () => error = cleanupStarted
            ? 'Some saved data may already be deleted, but account deletion did not finish. '
                  'Enter your password and retry to complete deletion.'
            : exception.code == 'invalid-credential' ||
                  exception.code == 'wrong-password'
            ? 'Password is incorrect. Please try again.'
            : 'Could not verify your account. Check your connection and password.',
      );
    } catch (_) {
      if (!mounted) return;
      setState(
        () => error = cleanupStarted
            ? 'Deletion stopped before finishing. Some saved data may already be deleted. '
                  'Check your connection and retry to complete deletion.'
            : 'Could not start deletion. Check your connection and try again.',
      );
    } finally {
      AccountStorage.deleting = false;
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48),
              const SizedBox(height: 20),
              Text(
                'Delete your account',
                style: TextStyle(
                  fontFamily: 'SnapSerif',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'This permanently removes your account and its saved customer '
                'data, including demo orders. There is no undo. Use a separate test '
                'account if you are testing this feature.',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: password,
                obscureText: true,
                enabled: !busy,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Current password',
                ),
                validator: (value) =>
                    (value ?? '').isEmpty ? 'Enter your password' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: confirmation,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Type DELETE to confirm',
                ),
                validator: (value) => value?.trim() == 'DELETE'
                    ? null
                    : 'Type DELETE in capital letters',
              ),
              const SizedBox(height: 24),
              if (error != null) ...[
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: 16),
              ],
              ElevatedButton(
                onPressed: busy ? null : deleteAccount,
                child: Text(busy ? 'DELETING… PLEASE WAIT' : 'DELETE ACCOUNT'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: busy ? null : () => Navigator.pop(context),
                child: const Text('KEEP MY ACCOUNT'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class PublishedCataloguePage extends StatefulWidget {
  final String? initialStore, initialCollection;
  final String initialQuery;
  const PublishedCataloguePage({
    super.key,
    this.initialStore,
    this.initialCollection,
    this.initialQuery = '',
  });
  @override
  State<PublishedCataloguePage> createState() => _PublishedCataloguePageState();
}

class _PublishedCataloguePageState extends State<PublishedCataloguePage> {
  String query = '';
  String? store;
  @override
  void initState() {
    super.initState();
    store = widget.initialStore;
    query = widget.initialQuery;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.initialCollection == null
            ? 'The local collection'
            : '${widget.initialCollection} collection',
      ),
      actions: [
        IconButton(
          tooltip: 'Nearby stores',
          icon: const Icon(Icons.near_me_outlined),
          onPressed: () async {
            final uid = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const NearbyStoresPage()),
            );
            if (uid != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PublishedCataloguePage(initialStore: uid),
                ),
              );
            }
          },
        ),
        IconButton(
          tooltip: 'Retailer basket',
          icon: const Icon(Icons.shopping_basket_outlined),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RetailerBasketPage()),
          ),
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publishedProducts')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: SelectableText('Could not load products: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No retailer products published yet.'),
          );
        }
        final docs = snapshot.data!.docs;
        final stores = <String, String>{
          for (final doc in docs)
            doc.data()['ownerUid'] as String: doc.data()['storeName'] as String,
        };
        final chosenStore = stores.containsKey(store) ? store : null;
        final filtered = docs.where((doc) {
          final d = doc.data();
          return (chosenStore == null || d['ownerUid'] == chosenStore) &&
              (widget.initialCollection == null ||
                  d['collection'] == widget.initialCollection) &&
              '${d['name']} ${d['brand']} ${d['category']} ${d['storeName']}'
                  .toLowerCase()
                  .contains(query.toLowerCase().trim());
        }).toList();
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Search clothes, brands or stores',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => query = value),
            ),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: chosenStore,
              hint: const Text('All stores'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('All stores'),
                ),
                ...stores.entries.map(
                  (entry) => DropdownMenuItem(
                    value: entry.key,
                    child: Text(entry.value),
                  ),
                ),
              ],
              onChanged: (value) => setState(() => store = value),
            ),
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No products match your search.'),
              ),
            const CustomerSection(
              label: 'THE LOCAL COLLECTION',
              title: 'Find your next favourite.',
              subtitle:
                  'Choose a store, explore its brands, and find your fit.',
            ),
            LayoutBuilder(
              builder: (context, bounds) => Wrap(
                spacing: 18,
                runSpacing: 18,
                children: filtered
                    .map(
                      (doc) => SizedBox(
                        width: bounds.maxWidth >= 950
                            ? (bounds.maxWidth - 36) / 3
                            : bounds.maxWidth >= 600
                            ? (bounds.maxWidth - 18) / 2
                            : bounds.maxWidth,
                        child: CustomerProductCard(
                          data: doc.data(),
                          onOpen: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => RetailerProductPage(id: doc.id),
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    ),
  );
}

class RetailerBasketItem {
  final String id, size, color;
  final int quantity;
  const RetailerBasketItem(this.id, this.size, this.color, this.quantity);
}

final retailerBasket = ValueNotifier<List<RetailerBasketItem>>([]);

class RetailerProductPage extends StatefulWidget {
  final String id;
  const RetailerProductPage({super.key, required this.id});
  @override
  State<RetailerProductPage> createState() => _RetailerProductPageState();
}

class _RetailerProductPageState extends State<RetailerProductPage> {
  String? selected;
  int quantity = 1;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Choose your fit')),
    body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('publishedProducts')
          .doc(widget.id)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Could not load product. Please reopen it.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final data = snapshot.data!.data();
        if (data == null) {
          return const Center(
            child: Text('This listing is no longer available.'),
          );
        }
        final variants = (data['variants'] as List).cast<Map>();
        final index = variants.indexWhere(
          (v) => '${v['size']}|${v['color']}' == selected,
        );
        final stock = index < 0 ? 0 : (variants[index]['stock'] as num).toInt();
        final valid = index >= 0 && quantity <= stock;
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: ColoredBox(
                color: const Color(0xFFF6EDE3),
                child: Image.network(
                  data['photoUrl'] as String,
                  webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                  height: 320,
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) => const SizedBox(
                    height: 200,
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
            ),
            const SizedBox(height: 24),
            Text(
              data['name'] as String,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),
            Text(
              '${data['storeName']} · ₹${(data['price'] as num).toStringAsFixed(2)}',
            ),
            Text(data['description'] as String),
            SaveRetailerPieceButton(productId: widget.id),
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      CompleteMyLookPage(initialProductId: widget.id),
                ),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Complete my look with this piece'),
            ),

            const SizedBox(height: 20),
            const CustomerSection(
              label: 'MAKE IT YOURS',
              title: 'Choose your fit.',
            ),
            Wrap(
              spacing: 8,
              children: variants.map((v) {
                final key = '${v['size']}|${v['color']}';
                final available = (v['stock'] as num) > 0;
                return ChoiceChip(
                  label: Text(
                    '${v['size']} / ${v['color']}${available ? '' : ' · sold out'}',
                  ),
                  selected: selected == key,
                  onSelected: available
                      ? (_) => setState(() {
                          selected = key;
                          quantity = 1;
                        })
                      : null,
                );
              }).toList(),
            ),
            Row(
              children: [
                IconButton(
                  onPressed: quantity > 1
                      ? () => setState(() => quantity--)
                      : null,
                  icon: const Icon(Icons.remove),
                ),
                Text('$quantity'),
                IconButton(
                  onPressed: quantity < stock
                      ? () => setState(() => quantity++)
                      : null,
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            if (index >= 0)
              Text(
                '$stock available · ₹${((data['price'] as num) * quantity).toStringAsFixed(2)}',
              ),
            FilledButton(
              onPressed: valid
                  ? () {
                      final v = variants[index];
                      final items = [...retailerBasket.value];
                      final existing = items.indexWhere(
                        (item) =>
                            item.id == widget.id &&
                            item.size == v['size'] &&
                            item.color == v['color'],
                      );
                      final total =
                          quantity +
                          (existing < 0 ? 0 : items[existing].quantity);
                      if (total > stock) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Your basket quantity would exceed available stock.',
                            ),
                          ),
                        );
                        return;
                      }
                      final item = RetailerBasketItem(
                        widget.id,
                        v['size'] as String,
                        v['color'] as String,
                        total,
                      );
                      if (existing < 0) {
                        items.add(item);
                      } else {
                        items[existing] = item;
                      }
                      retailerBasket.value = items;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const RetailerBasketPage(),
                        ),
                      );
                    }
                  : null,
              child: const Text('ADD TO BAG'),
            ),
            const CustomerNotice(
              'Items stay in your bag for this session. Stock is reserved when your order is placed.',
            ),
          ],
        );
      },
    ),
  );
}

class RetailerBasketPage extends StatelessWidget {
  const RetailerBasketPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Your bag')),
    body: ValueListenableBuilder<List<RetailerBasketItem>>(
      valueListenable: retailerBasket,
      builder: (context, items, _) {
        if (items.isEmpty) {
          return const Center(
            child: Text('Your bag is waiting for your next look.'),
          );
        }
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('publishedProducts')
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Cannot check current prices and stock. Please try again.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final listings = {
              for (final doc in snapshot.data!.docs) doc.id: doc.data(),
            };
            num total = 0;
            bool allAvailable = true;
            final cards = items.map((item) {
              final data = listings[item.id];
              final matches = ((data?['variants'] as List?) ?? [])
                  .cast<Map>()
                  .where(
                    (v) => v['size'] == item.size && v['color'] == item.color,
                  );
              final stock = matches.isEmpty
                  ? 0
                  : (matches.first['stock'] as num).toInt();
              final available = data != null && stock >= item.quantity;
              if (!available) {
                allAvailable = false;
              }
              final subtotal = (data?['price'] as num? ?? 0) * item.quantity;
              if (available) {
                total += subtotal;
              }
              return Card(
                child: ListTile(
                  title: Text(data?['name'] as String? ?? 'Listing removed'),
                  subtitle: Text(
                    '${item.size} / ${item.color} · ${item.quantity} pieces\n${available ? '₹${subtotal.toStringAsFixed(2)}' : 'Unavailable at this quantity — $stock left'}',
                  ),
                  trailing: IconButton(
                    tooltip: 'Remove',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => retailerBasket.value = items
                        .where((entry) => !identical(entry, item))
                        .toList(),
                  ),
                ),
              );
            }).toList();
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const CustomerSection(
                  label: 'YOUR BAG',
                  title: 'A little style. A lot of you.',
                  subtitle: 'Review your fit before checkout.',
                ),
                ...cards,
                const SizedBox(height: 16),
                Text(
                  '${allAvailable ? 'Items subtotal' : 'Available items subtotal'}: ₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 22),
                ),
                const CustomerNotice(
                  'Prices and availability are checked again when you place your order.',
                ),
                FilledButton(
                  onPressed: allAvailable
                      ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ClothingCheckoutPage(),
                          ),
                        )
                      : null,
                  child: const Text('CHECKOUT'),
                ),
              ],
            );
          },
        );
      },
    ),
  );
}

class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key});
  @override
  State<DiscoverPage> createState() => _StitchHomeState();
}

class _StitchHomeState extends State<DiscoverPage> {
  final search = TextEditingController();
  String category = 'All';
  bool onlyInStock = false;
  bool priceAscending = false;
  String? brand, size;
  double? budget;
  late Stream<QuerySnapshot<Map<String, dynamic>>> listings;
  @override
  void initState() {
    super.initState();
    listings = FirebaseFirestore.instance
        .collection('publishedProducts')
        .snapshots();
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void open(Widget page) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  Future<void> searchNearby(String query) async {
    final uid = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => NearbyStoresPage(initialQuery: query)),
    );
    if (uid != null && mounted) {
      open(PublishedCataloguePage(initialStore: uid, initialQuery: query));
    }
  }

  Future<void> filters(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final sizes = <String>{};
    for (final doc in docs) {
      for (final v in (doc.data()['variants'] as List).cast<Map>()) {
        sizes.add(v['size'] as String);
      }
    }
    String? pickedSize = size;
    double? pickedBudget = budget;
    final sortedSizes = sizes.toList()..sort();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Find your fit',
                  style: TextStyle(
                    fontFamily: 'SnapSerif',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Size'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: pickedSize == null,
                      onSelected: (_) => setSheet(() => pickedSize = null),
                    ),
                    ...sortedSizes.map(
                      (value) => ChoiceChip(
                        label: Text(value),
                        selected: pickedSize == value,
                        onSelected: (_) => setSheet(() => pickedSize = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Maximum item price'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Any'),
                      selected: pickedBudget == null,
                      onSelected: (_) => setSheet(() => pickedBudget = null),
                    ),
                    ...[1000.0, 2000.0, 5000.0].map(
                      (value) => ChoiceChip(
                        label: Text('₹${value.toInt()}'),
                        selected: pickedBudget == value,
                        onSelected: (_) => setSheet(() => pickedBudget = value),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () {
                    setState(() {
                      size = pickedSize;
                      budget = pickedBudget;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('APPLY FILTERS'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const RoyalWordmark(),
      actions: [
        IconButton(
          tooltip: 'Nearby stores',
          icon: const Icon(Icons.near_me_outlined),
          onPressed: () async {
            final uid = await Navigator.push<String>(
              context,
              MaterialPageRoute(builder: (_) => const NearbyStoresPage()),
            );
            if (uid != null && mounted) {
              open(PublishedCataloguePage(initialStore: uid));
            }
          },
        ),
        IconButton(
          tooltip: 'Retailer basket',
          icon: const Icon(Icons.shopping_bag_outlined),
          onPressed: () => open(const RetailerBasketPage()),
        ),
        PopupMenuButton<String>(
          onSelected: (_) => open(const SampleCollectionPage()),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'demo',
              child: Text('Sample collection & demo cart'),
            ),
          ],
        ),
      ],
    ),
    body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: listings,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load retailer products.'),
                TextButton(
                  onPressed: () => setState(
                    () => listings = FirebaseFirestore.instance
                        .collection('publishedProducts')
                        .snapshots(),
                  ),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final categories = <String>{
          'All',
          ...docs.map((d) => d.data()['category'] as String),
        }.where((c) => c.isNotEmpty).toList();
        final brands =
            docs
                .map((d) => d.data()['brand'] as String)
                .where((b) => b.isNotEmpty)
                .toSet()
                .toList()
              ..sort();
        final selectedCategory = categories.contains(category)
            ? category
            : 'All';
        final selectedBrand = brands.contains(brand) ? brand : null;
        final filtered = docs.where((doc) {
          final d = doc.data();
          return (!onlyInStock ||
                  (d['variants'] as List).cast<Map>().any(
                    (v) => (v['stock'] as num) > 0,
                  )) &&
              (selectedCategory == 'All' ||
                  d['category'] == selectedCategory) &&
              (selectedBrand == null || d['brand'] == selectedBrand) &&
              (budget == null || (d['price'] as num) <= budget!) &&
              (size == null ||
                  (d['variants'] as List).cast<Map>().any(
                    (v) => v['size'] == size && (v['stock'] as num) > 0,
                  )) &&
              '${d['name']} ${d['storeName']} ${d['brand']}'
                  .toLowerCase()
                  .contains(search.text.toLowerCase().trim());
        }).toList();
        if (priceAscending) {
          filtered.sort(
            (a, b) =>
                (a.data()['price'] as num).compareTo(b.data()['price'] as num),
          );
        }
        final stores =
            <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
        for (final doc in filtered.where((_) => search.text.trim().isEmpty)) {
          stores
              .putIfAbsent(doc.data()['ownerUid'] as String, () => [])
              .add(doc);
        }
        final reduce = MediaQuery.of(context).disableAnimations;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
          children: [
            ValueListenableBuilder<ProfileDetails>(
              valueListenable: profileDetails,
              builder: (context, details, _) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E4C7),
                  child: Icon(Icons.location_on_outlined, color: royalInk),
                ),
                title: const Text(
                  'Deliver to',
                  style: TextStyle(fontSize: 11, color: royalGold),
                ),
                subtitle: Text(
                  details.address.isEmpty
                      ? 'Choose your delivery area'
                      : details.address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: royalInk,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                trailing: const Icon(
                  Icons.keyboard_arrow_down,
                  color: royalInk,
                ),
                onTap: () => open(const EditProfilePage()),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              textInputAction: TextInputAction.search,
              onSubmitted: (value) => searchNearby(value.trim()),
              decoration: InputDecoration(
                hintText: 'Search an item in nearby stores',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Find item nearby',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => searchNearby(search.text.trim()),
                ),
              ),
            ),
            const SizedBox(height: 22),
            SnapDiscoverBanner(onExplore: () => open(const NearbyStoresPage())),
            const SizedBox(height: 24),
            const Text(
              'What are you looking for?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: royalInk,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Explore what your local boutiques have in store.',
              style: TextStyle(color: Color(0xFF756D60), fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: categories.length,
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                itemBuilder: (context, index) {
                  final value = categories[index];
                  final candidates = docs.where(
                    (d) => value == 'All' || d.data()['category'] == value,
                  );
                  final photo = candidates.isEmpty
                      ? null
                      : candidates.first.data()['photoUrl'] as String?;
                  return Semantics(
                    selected: selectedCategory == value,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => category = value),
                      child: SizedBox(
                        width: 88,
                        child: Column(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selectedCategory == value
                                    ? royalGold
                                    : const Color(0xFFECE4D6),
                              ),
                              child: CircleAvatar(
                                radius: 35,
                                backgroundColor: royalCream,
                                child: ClipOval(
                                  child: photo == null
                                      ? const Icon(
                                          Icons.checkroom,
                                          size: 32,
                                          color: royalInk,
                                        )
                                      : Image.network(
                                          photo,
                                          width: 70,
                                          height: 70,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, _, _) => const Icon(
                                            Icons.checkroom,
                                            size: 32,
                                            color: royalInk,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 9),
                            Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: selectedCategory == value
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                                color: royalInk,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Card(
              color: const Color(0xFFF3E4C7),
              child: ListTile(
                contentPadding: const EdgeInsets.all(18),
                leading: const Icon(Icons.auto_awesome, color: royalInk),
                title: const Text(
                  'Complete My Look',
                  style: TextStyle(
                    fontFamily: 'SnapSerif',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: const Text('One piece. A whole look. Your budget.'),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => open(const CompleteMyLookPage()),
              ),
            ),
            const SizedBox(height: 16),
            SnapFitPanel(
              size: size,
              budget: budget,
              matches: filtered.length,
              onChoose: () => filters(docs),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('In stock'),
                    selected: onlyInStock,
                    avatar: const Icon(Icons.inventory_2_outlined, size: 16),
                    onSelected: (v) => setState(() => onlyInStock = v),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Price: low to high'),
                    selected: priceAscending,
                    avatar: const Icon(Icons.sort, size: 16),
                    onSelected: (v) => setState(() => priceAscending = v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () => filters(docs),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(
                    size == null && budget == null
                        ? 'Size & budget'
                        : 'Filters applied',
                  ),
                ),
                const Spacer(),
                if (onlyInStock ||
                    priceAscending ||
                    size != null ||
                    budget != null ||
                    selectedBrand != null ||
                    search.text.isNotEmpty ||
                    selectedCategory != 'All')
                  TextButton(
                    onPressed: () => setState(() {
                      onlyInStock = false;
                      priceAscending = false;
                      size = null;
                      budget = null;
                      brand = null;
                      category = 'All';
                      search.clear();
                    }),
                    child: const Text('Clear'),
                  ),
              ],
            ),
            if (brands.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Shop by brand',
                style: TextStyle(
                  fontFamily: 'SnapSerif',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: brands
                      .map(
                        (b) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(b),
                            selected: selectedBrand == b,
                            onSelected: (value) =>
                                setState(() => brand = value ? b : null),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (search.text.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => searchNearby(search.text.trim()),
                icon: const Icon(Icons.near_me_outlined),
                label: const Text('Find this item in nearby stores'),
              ),
              const Text(
                'Choose a PIN or use your location to see stores with matching stock.',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (filtered.isNotEmpty && search.text.trim().isEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'The local edit',
                style: TextStyle(
                  fontFamily: 'SnapSerif',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Real pieces from the stores below. Tap to explore.',
                style: TextStyle(fontSize: 12, color: Color(0xFF756D60)),
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 260,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: filtered.length > 8 ? 8 : filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 14),
                  itemBuilder: (context, index) {
                    final item = filtered[index].data();
                    return SizedBox(
                      width: 180,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () => open(
                          PublishedCataloguePage(
                            initialStore: item['ownerUid'] as String,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.network(
                                item['photoUrl'] as String,
                                width: 180,
                                height: 168,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const SizedBox(
                                  height: 168,
                                  child: Center(
                                    child: Icon(Icons.checkroom, size: 40),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              item['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '₹${(item['price'] as num).toStringAsFixed(0)}',
                              style: const TextStyle(
                                color: royalInk,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              item['storeName'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF756D60),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Boutiques to explore',
                    style: TextStyle(
                      fontFamily: 'SnapSerif',
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text('${stores.length} stores'),
              ],
            ),
            const SizedBox(height: 12),
            if (stores.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  search.text.trim().isNotEmpty
                      ? 'Tap Find this item in nearby stores to search your area.'
                      : docs.isEmpty
                      ? 'No retailer products published yet.'
                      : 'No stores match these filters. Try another size or budget.',
                ),
              ),
            ...stores.entries.map((entry) {
              final first = entry.value.first.data();
              final storeBrands = entry.value
                  .map((doc) => doc.data()['brand'] as String)
                  .toSet()
                  .join(' · ');
              final card = Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: const Color(0xFFE6E4DC)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                      child: Image.network(
                        first['photoUrl'] as String,
                        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, error, stack) => const SizedBox(
                          height: 140,
                          child: Center(child: Icon(Icons.checkroom, size: 48)),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            first['storeName'] as String,
                            style: TextStyle(
                              fontFamily: 'SnapSerif',
                              fontSize: 25,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(storeBrands),
                          Text('${entry.value.length} matching products'),
                          const SizedBox(height: 14),
                          StitchPressButton(
                            label: 'OPEN STORE',
                            onPressed: () => open(
                              PublishedCataloguePage(initialStore: entry.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
              return reduce
                  ? card
                  : TweenAnimationBuilder<double>(
                      key: ValueKey(
                        '${entry.key}|$selectedCategory|$selectedBrand|$size|$budget|${search.text}',
                      ),
                      tween: Tween(begin: 0, end: 1),
                      duration: const Duration(milliseconds: 280),
                      curve: Curves.easeOutCubic,
                      child: card,
                      builder: (_, value, child) => Opacity(
                        opacity: value,
                        child: Transform.translate(
                          offset: Offset(0, 8 * (1 - value)),
                          child: child,
                        ),
                      ),
                    );
            }),
            const SizedBox(height: 16),
            const RoyalHowItWorks(),
            const SizedBox(height: 20),
            RoyalFooter(onAccount: () => open(const ProfilePage())),
          ],
        );
      },
    ),
  );
}

class StitchPressButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  const StitchPressButton({
    super.key,
    required this.label,
    required this.onPressed,
  });
  @override
  State<StitchPressButton> createState() => _StitchPressButtonState();
}

class _StitchPressButtonState extends State<StitchPressButton> {
  bool pressed = false;
  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => pressed = true),
    onPointerUp: (_) => setState(() => pressed = false),
    onPointerCancel: (_) => setState(() => pressed = false),
    child: AnimatedScale(
      scale: pressed && !MediaQuery.of(context).disableAnimations ? .97 : 1,
      duration: MediaQuery.of(context).disableAnimations
          ? Duration.zero
          : const Duration(milliseconds: 120),
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: snapTerracotta,
          foregroundColor: snapCream,
          minimumSize: const Size(double.infinity, 48),
        ),
        onPressed: widget.onPressed,
        child: Text(widget.label),
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
            padding: const EdgeInsets.all(20),
            children: [
              const CustomerSection(
                label: 'YOUR ORDERS',
                title: 'From store to doorstep.',
                subtitle:
                    'Follow preparation, pickup and delivery in one place.',
              ),
              ...docs.map(
                (doc) => ClothingOrderCard(
                  id: doc.id,
                  data: doc.data(),
                  retailer: retailer,
                  admin: admin,
                ),
              ),
            ],
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
            CustomerOrderProgress(status: d['status'] as String),
            Text(
              '₹${((d['totalPaise'] as num) / 100).toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: snapForest,
              ),
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
            if (!widget.retailer &&
                !widget.admin &&
                ['assigned', 'picked_up'].contains(d['status']))
              DeliveryCodePanel(orderId: widget.id),
            if (!widget.retailer && !widget.admin)
              CustomerReceiptButton(orderId: widget.id, order: d),
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

class ClothingCheckoutPage extends StatefulWidget {
  const ClothingCheckoutPage({super.key});
  @override
  State<ClothingCheckoutPage> createState() => _ClothingCheckoutPageState();
}

class _ClothingCheckoutPageState extends State<ClothingCheckoutPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      address = TextEditingController(),
      city = TextEditingController(),
      pin = TextEditingController();
  final items = [...retailerBasket.value];
  final requestId = FirebaseFirestore.instance
      .collection('clothingOrders')
      .doc()
      .id;
  bool busy = false;
  String method = 'cod';
  String? error;
  Map<String, dynamic>? frozenRequest;
  @override
  void dispose() {
    for (final c in [name, phone, address, city, pin]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> submit(int expectedTotalPaise) async {
    if (!form.currentState!.validate()) {
      return;
    }
    if (FirebaseAuth.instance.currentUser == null) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AccountPage()),
      );
      if (!mounted) {
        return;
      }
      setState(
        () => error = FirebaseAuth.instance.currentUser == null
            ? 'Sign in to place your order. Your delivery details are still here.'
            : 'You are signed in. Review your details and place your order.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    frozenRequest ??= {
      'requestId': requestId,
      'paymentMethod': method,
      'expectedTotalPaise': expectedTotalPaise,
      'items': items
          .map(
            (i) => {
              'id': i.id,
              'size': i.size,
              'color': i.color,
              'quantity': i.quantity,
            },
          )
          .toList(),
      'address': {
        'name': name.text.trim(),
        'phone': phone.text.trim(),
        'address': address.text.trim(),
        'city': city.text.trim(),
        'pin': pin.text.trim(),
      },
    };
    try {
      await clothingCall('placeClothingOrder', frozenRequest!);
      if (mounted) {
        retailerBasket.value = [];
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ClothingOrdersPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error =
              '$e\nIf the result is uncertain, retry without changing this checkout. Reopening creates a new request. Check Orders before placing it again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('publishedProducts')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = {for (final d in snapshot.data!.docs) d.id: d.data()};
          final owners = items.map((i) => docs[i.id]?['ownerUid']).toSet();
          if (items.isEmpty || owners.length != 1 || owners.contains(null)) {
            return const Center(
              child: Text(
                'Checkout supports one store per order. Review your basket.',
              ),
            );
          }
          final owner = owners.single as String;
          int subtotal = 0;
          bool available = true;
          for (final i in items) {
            final d = docs[i.id]!;
            final v = (d['variants'] as List).cast<Map>().where(
              (v) => v['size'] == i.size && v['color'] == i.color,
            );
            if (v.isEmpty || (v.first['stock'] as num) < i.quantity) {
              available = false;
            }
            subtotal += ((d['price'] as num) * 100).round() * i.quantity;
          }
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('checkoutSettings')
                .doc(owner)
                .snapshots(),
            builder: (context, settings) {
              final cfg = settings.data?.data();
              final fee = (cfg?['deliveryFeePaise'] as num?)?.toInt();
              final enabled = cfg?['enabled'] == true && fee != null;
              final servicePins =
                  (cfg?['servicePins'] as List?)?.cast<String>() ?? [];
              final eligible =
                  enabled && available && servicePins.contains(pin.text.trim());
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  const CustomerSection(
                    label: 'CHECKOUT',
                    title: 'Your next look, on its way.',
                    subtitle:
                        'Add your delivery details and review your total.',
                  ),
                  Form(
                    key: form,
                    child: Column(
                      children: [
                        for (final entry in <TextEditingController, String>{
                          name: 'Name',
                          phone: 'Phone',
                          address: 'House / street / area',
                          city: 'City',
                          pin: 'PIN',
                        }.entries)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: TextFormField(
                              controller: entry.key,
                              enabled: !busy && frozenRequest == null,
                              maxLength: entry.key == phone
                                  ? 10
                                  : entry.key == pin
                                  ? 6
                                  : 300,
                              keyboardType:
                                  entry.key == phone || entry.key == pin
                                  ? TextInputType.number
                                  : TextInputType.text,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(
                                labelText: entry.value,
                              ),
                              validator: (v) {
                                final t = v?.trim() ?? '';
                                if (t.isEmpty) {
                                  return 'Required';
                                }
                                if (entry.key == phone &&
                                    !RegExp(r'^[6-9][0-9]{9}$').hasMatch(t)) {
                                  return 'Enter a valid phone';
                                }
                                if (entry.key == pin &&
                                    !RegExp(r'^[1-9][0-9]{5}$').hasMatch(t)) {
                                  return 'Enter a valid PIN';
                                }
                                return null;
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                  AddressSuggestions(
                    pin: pin,
                    address: address,
                    city: city,
                    enabled: !busy && frozenRequest == null,
                  ),
                  if (FirebaseAuth.instance.currentUser != null)
                    const EmailVerificationCard(),
                  const Text(
                    'Email receipts use your verified account email. A copyable receipt is available in Orders.',
                  ),
                  Text('Items: ₹${(subtotal / 100).toStringAsFixed(2)}'),
                  Text(
                    fee == null
                        ? 'Delivery fee not configured'
                        : 'Delivery: ₹${(fee / 100).toStringAsFixed(2)}',
                  ),
                  if (enabled)
                    Text(
                      'Total: ₹${((subtotal + fee) / 100).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (!enabled)
                    const Text(
                      'Store checkout has not been enabled by the owner.',
                    ),
                  if (enabled && !servicePins.contains(pin.text.trim()))
                    const Text('Enter a PIN served by this store.'),
                  ListTile(
                    leading: const Icon(Icons.payments_outlined),
                    title: const Text('Cash on delivery'),
                    subtitle: const Text(
                      'Payment stays unpaid until collection.',
                    ),
                  ),
                  const ListTile(
                    leading: Icon(Icons.credit_card_outlined),
                    title: Text('Online payment — setup pending'),
                    subtitle: Text(
                      'A payment gateway account must be connected and tested.',
                    ),
                  ),
                  const CustomerNotice(
                    'Your store confirms and prepares the order. A rider is assigned automatically when it is ready. Local testing only.',
                    icon: Icons.local_shipping_outlined,
                  ),
                  if (error != null)
                    SelectableText(
                      error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  FilledButton(
                    onPressed: busy || !eligible
                        ? null
                        : () => submit(subtotal + fee),
                    child: Text(busy ? 'Placing order…' : 'PLACE COD ORDER'),
                  ),
                ],
              );
            },
          );
        },
      ),
    ),
  );
}

class DeliveryCodePanel extends StatelessWidget {
  final String orderId;
  const DeliveryCodePanel({super.key, required this.orderId});
  @override
  Widget build(BuildContext context) =>
      StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('deliveryCodes')
            .doc(orderId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Text(
              'Could not load delivery code. Retry when connected.',
            );
          }
          final code = snapshot.data?.data()?['code'];
          if (code == null) {
            return const Text(
              'Delivery code unavailable for this older test order. Test with a new order.',
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Delivery code',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SelectableText(
                  '$code',
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 4,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Text(
                  'Share this code with the rider only after receiving your clothes. Local test: no SMS is sent.',
                ),
              ],
            ),
          );
        },
      );
}

class SnapDiscoverBanner extends StatelessWidget {
  final VoidCallback onExplore;
  const SnapDiscoverBanner({super.key, required this.onExplore});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth > 650;
      final copy = Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'YOUR NEIGHBOURHOOD. YOUR STYLE.',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.6,
                color: royalGold,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Great style.\nCloser than you think.',
              style: TextStyle(
                fontFamily: 'SnapSerif',
                fontSize: wide ? 42 : 34,
                height: 1.05,
                color: royalInk,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Discover local boutiques. Find your fit.\nLet SnapWear bring it to your door.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF645B4A),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onExplore,
              icon: const Icon(Icons.near_me_outlined, size: 18),
              label: const Text('Explore near you'),
            ),
          ],
        ),
      );
      final photo = Image.asset(
        'assets/royal-hero.webp',
        fit: BoxFit.cover,
        height: wide ? 300 : 175,
        width: double.infinity,
        alignment: Alignment.centerRight,
      );
      return Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: const Color(0xFFF3E8D2),
              child: wide
                  ? Row(
                      children: [
                        Expanded(child: copy),
                        Expanded(child: photo),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [copy, photo],
                    ),
            ),
          ),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 22,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _SnapPromise(
                icon: Icons.storefront_outlined,
                label: 'Local boutiques',
              ),
              _SnapPromise(
                icon: Icons.checkroom_outlined,
                label: 'Find your fit',
              ),
              _SnapPromise(
                icon: Icons.delivery_dining_outlined,
                label: 'Doorstep delivery',
              ),
            ],
          ),
        ],
      );
    },
  );
}

class _SnapPromise extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SnapPromise({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 17, color: royalGold),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, color: royalInk)),
    ],
  );
}

class SnapFitPanel extends StatelessWidget {
  final String? size;
  final double? budget;
  final int matches;
  final VoidCallback onChoose;
  const SnapFitPanel({
    super.key,
    this.size,
    this.budget,
    required this.matches,
    required this.onChoose,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: royalInk,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.tune_rounded, color: Color(0xFFE5C586), size: 20),
            SizedBox(width: 8),
            Text(
              'SNAPWEAR · FIT FIRST',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                color: Color(0xFFE5C586),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        const Text(
          'Your size. Your budget. Your local edit.',
          style: TextStyle(
            fontFamily: 'SnapSerif',
            fontSize: 26,
            color: royalCream,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          size == null && budget == null
              ? 'Choose your fit to narrow down the pieces you can actually shop.'
              : '${size == null ? 'Any size' : 'Size $size'} · ${budget == null ? 'Any budget' : 'Up to ₹${budget!.toInt()}'} · $matches matching products',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFFD8DFD5),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEED7AA),
            foregroundColor: royalInk,
          ),
          onPressed: onChoose,
          icon: const Icon(Icons.arrow_forward, size: 17),
          label: Text(
            size == null && budget == null ? 'Find my fit' : 'Adjust my fit',
          ),
        ),
      ],
    ),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _CustomerShellState();
}

class _CustomerShellState extends State<HomePage> {
  final controller = PageController();
  final navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final pages = const <Widget>[
    DiscoverPage(),
    PublishedCataloguePage(),
    RetailerBasketPage(),
    ClothingOrdersPage(),
    ProfilePage(),
  ];
  int selected = 0;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void select(int index) {
    if (selected == index) {
      navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    if (MediaQuery.of(context).disableAnimations) {
      controller.jumpToPage(index);
    } else {
      controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
      child: PageView(
        controller: controller,
        onPageChanged: (index) => setState(() => selected = index),
        children: [
          for (var i = 0; i < pages.length; i++)
            _KeepCustomerTab(
              child: NavigatorPopHandler<Object?>(
                enabled: selected == i,
                onPopWithResult: (_) =>
                    navigatorKeys[i].currentState?.maybePop(),
                child: Navigator(
                  key: navigatorKeys[i],
                  onGenerateRoute: (_) =>
                      MaterialPageRoute(builder: (_) => pages[i]),
                ),
              ),
            ),
        ],
      ),
    ),
    bottomNavigationBar: NavigationBar(
      selectedIndex: selected,
      indicatorColor: lime,
      onDestinationSelected: select,
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.explore_outlined),
          label: 'Discover',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined),
          label: 'Stores',
        ),
        NavigationDestination(
          icon: Icon(Icons.shopping_bag_outlined),
          label: 'Basket',
        ),
        NavigationDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: 'Orders',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Account',
        ),
      ],
    ),
  );
}

class _KeepCustomerTab extends StatefulWidget {
  final Widget child;
  const _KeepCustomerTab({required this.child});
  @override
  State<_KeepCustomerTab> createState() => _KeepCustomerTabState();
}

class _KeepCustomerTabState extends State<_KeepCustomerTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}

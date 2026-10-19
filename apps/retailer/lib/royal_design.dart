import 'package:flutter/material.dart';

const royalCream = Color(0xFFFFF8EA);
const royalInk = Color(0xFF193C37);
const royalGold = Color(0xFFAA843D);

class RoyalWordmark extends StatelessWidget {
  final String? role;
  const RoyalWordmark({super.key, this.role});
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.shopping_bag_outlined, color: royalInk, size: 26),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          role == null ? 'SNAPWEAR' : 'SNAPWEAR · $role',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'SnapSerif',
            fontSize: 21,
            color: royalInk,
            letterSpacing: .6,
          ),
        ),
      ),
    ],
  );
}

class RoyalFrame extends StatelessWidget {
  final Widget child;
  const RoyalFrame({super.key, required this.child});
  @override
  Widget build(BuildContext context) => ColoredBox(
    color: royalCream,
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1240),
        child: child,
      ),
    ),
  );
}

class RoyalLandingHero extends StatelessWidget {
  final VoidCallback onExplore, onHow;
  const RoyalLandingHero({
    super.key,
    required this.onExplore,
    required this.onHow,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 760;
      final copy = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'LOCAL BOUTIQUES. CLOSER TO YOU.',
            style: TextStyle(color: royalGold, fontSize: 10, letterSpacing: 2),
          ),
          const SizedBox(height: 16),
          Text(
            'Fashion near you.',
            style: TextStyle(
              fontFamily: 'SnapSerif',
              color: royalInk,
              fontSize: wide ? 46 : 36,
              height: 1.05,
            ),
          ),
          Text(
            'delivered beautifully.',
            style: TextStyle(
              fontFamily: 'SnapSerif',
              fontStyle: FontStyle.italic,
              color: royalGold,
              fontSize: wide ? 43 : 34,
              height: 1.12,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Discover independent boutiques, curated pieces\nand a more personal kind of delivery.',
            style: TextStyle(
              color: Color(0xFF645B4A),
              fontSize: 14,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 14,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              FilledButton.icon(
                onPressed: onExplore,
                label: const Text('Explore near you'),
                icon: const Icon(Icons.arrow_forward, size: 17),
                style: FilledButton.styleFrom(
                  backgroundColor: royalInk,
                  foregroundColor: royalCream,
                ),
              ),
              TextButton.icon(
                onPressed: onHow,
                icon: const Icon(Icons.play_circle_outline, color: royalGold),
                label: const Text('How it works'),
              ),
            ],
          ),
        ],
      );
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: wide
            ? SizedBox(
                height: 380,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset('assets/royal-hero.webp', fit: BoxFit.cover),
                    Positioned(
                      left: 32,
                      top: 44,
                      width: bounds.maxWidth * .46,
                      child: copy,
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(padding: const EdgeInsets.all(22), child: copy),
                  Image.asset(
                    'assets/royal-hero.webp',
                    height: 200,
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                  ),
                ],
              ),
      );
    },
  );
}

class RoyalHowItWorks extends StatelessWidget {
  const RoyalHowItWorks({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFF9EFDA),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'How SnapWear works',
          style: TextStyle(
            fontFamily: 'SnapSerif',
            color: royalInk,
            fontSize: 26,
          ),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, bounds) => Wrap(
            spacing: 16,
            runSpacing: 22,
            children: List.generate(4, (i) {
              const titles = [
                'Choose your area',
                'Explore collections',
                'Place your order',
                'Local delivery',
              ];
              const detail = [
                'Find participating boutiques near you.',
                'Choose your clothes, size and colour.',
                'Your boutique accepts and prepares it.',
                'Follow pickup and delivery updates.',
              ];
              const icons = [
                Icons.location_on_outlined,
                Icons.shopping_bag_outlined,
                Icons.receipt_long_outlined,
                Icons.two_wheeler,
              ];
              return SizedBox(
                width: bounds.maxWidth >= 900
                    ? (bounds.maxWidth - 48) / 4
                    : bounds.maxWidth >= 450
                    ? (bounds.maxWidth - 16) / 2
                    : bounds.maxWidth,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icons[i], color: royalGold, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '0${i + 1}',
                            style: const TextStyle(
                              color: royalGold,
                              fontSize: 10,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            titles[i],
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            detail[i],
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.5,
                              color: Color(0xFF756A58),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    ),
  );
}

class RoyalCollections extends StatelessWidget {
  final void Function(String) onSelect;
  const RoyalCollections({super.key, required this.onSelect});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Curated for every you.',
        style: TextStyle(fontFamily: 'SnapSerif', fontSize: 30, color: royalInk),
      ),
      const SizedBox(height: 10),
      const Text(
        'Explore local collections. Availability depends on your participating boutiques.',
        style: TextStyle(fontSize: 12, color: Color(0xFF756A58)),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, bounds) {
          final columns = bounds.maxWidth >= 850 ? 4 : 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: List.generate(4, (i) {
              const labels = ['Women', 'Men', 'Accessories', 'Kids'];
              const subtitles = [
                'Everyday to elevated',
                'Modern essentials',
                'The finishing touch',
                'Little looks, big moments',
              ];
              return SizedBox(
                width: (bounds.maxWidth - (columns - 1) * 14) / columns,
                child: Semantics(
                  button: true,
                  label: '${labels[i]} collection',
                  child: InkWell(
                    onTap: () => onSelect(labels[i]),
                    borderRadius: BorderRadius.circular(18),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 170,
                            child: LayoutBuilder(
                              builder: (_, tile) => ClipRect(
                                child: OverflowBox(
                                  alignment: Alignment(
                                    i.isEven ? -1 : 1,
                                    i < 2 ? -1 : 1,
                                  ),
                                  minWidth: tile.maxWidth * 2,
                                  maxWidth: tile.maxWidth * 2,
                                  minHeight: 340,
                                  maxHeight: 340,
                                  child: Image.asset(
                                    'assets/royal-collections.webp',
                                    width: tile.maxWidth * 2,
                                    height: 340,
                                    fit: BoxFit.fill,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ColoredBox(
                            color: const Color(0xFFF4E7D0),
                            child: Padding(
                              padding: const EdgeInsets.all(13),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          labels[i],
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          subtitles[i],
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.arrow_forward, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          );
        },
      ),
    ],
  );
}

class RoyalFooter extends StatelessWidget {
  final VoidCallback onAccount;
  const RoyalFooter({super.key, required this.onAccount});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(top: 26),
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(
      color: royalInk,
      borderRadius: BorderRadius.circular(22),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Take SnapWear with you.',
          style: TextStyle(
            fontFamily: 'SnapSerif',
            fontSize: 27,
            color: royalCream,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Shop local boutiques, follow your orders and find your next favourite.',
          style: TextStyle(color: Color(0xFFE5D8BA), height: 1.5),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onAccount,
          style: OutlinedButton.styleFrom(
            foregroundColor: royalCream,
            side: const BorderSide(color: royalGold),
          ),
          child: const Text('Your SnapWear account'),
        ),
      ],
    ),
  );
}

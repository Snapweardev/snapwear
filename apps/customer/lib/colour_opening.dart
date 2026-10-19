import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Select with SNAPWEAR_OPENING_COLOUR=arctic|lace|bubblegum|sage.
/// The real app page stays mounted underneath the illustrated opening.
class FourColourOpening extends StatefulWidget {
  final Widget child;
  const FourColourOpening({super.key, required this.child});
  @override
  State<FourColourOpening> createState() => _FourColourOpeningState();
}

class _FourColourOpeningState extends State<FourColourOpening>
    with SingleTickerProviderStateMixin {
  late final controller =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 4950),
      )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => finished = true);
        }
      });
  final images = <ui.Image>[];
  bool started = false, finished = false;
  static const names = ['arctic', 'lace', 'bubblegum', 'sage'];
  int get palette => math.max(0, names.indexOf('arctic'));
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (started) {
      return;
    }
    started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.duration = const Duration(milliseconds: 250);
    }
    _load();
  }

  Future<void> _load() async {
    try {
      for (final name in ['cream-atlas', 'cream-garments']) {
        final bytes = await rootBundle.load('assets/opening-$name.webp');
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        images.add(frame.image);
      }
    } catch (_) {
      /* Opening failure must never prevent access to the app. */
    }
    if (mounted) {
      setState(() {});
      controller.forward();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    for (final image in images) {
      image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        ignoring: !finished,
        child: ExcludeSemantics(excluding: !finished, child: widget.child),
      ),
      if (!finished)
        AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            final reduced = MediaQuery.disableAnimationsOf(context),
                seconds = controller.value * 4.95;
            final reveal = reduced
                ? controller.value
                : Curves.easeInOut.transform(
                    ((seconds - 4.25) / .65).clamp(0.0, 1.0),
                  );
            return Opacity(
              opacity: 1 - reveal,
              child: ColoredBox(
                color: const Color(0xFFFFF4DF),
                child: SafeArea(
                  child: LayoutBuilder(
                    builder: (context, bounds) {
                      final width = math.min(420.0, bounds.maxWidth),
                          height = math.min(bounds.maxHeight, width * 17 / 9);
                      return Center(
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: CustomPaint(
                                  painter: _ColourOpeningPainter(
                                    images,
                                    palette,
                                    seconds,
                                    reduced,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: height * .074,
                                left: 0,
                                right: 0,
                                child: Column(
                                  children: [
                                    SizedBox(
                                      width: 32,
                                      height: 43,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          Positioned(
                                            top: 0,
                                            child: Container(
                                              width: 18,
                                              height: 14,
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF053229,
                                                  ),
                                                  width: 3,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(9),
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 32,
                                            height: 34,
                                            alignment: Alignment.center,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF053229),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: const Text(
                                              'S',
                                              style: TextStyle(
                                                fontFamily: 'SnapSerif',
                                                fontSize: 28,
                                                color: Color(0xFFFFEDD1),
                                                decoration: TextDecoration.none,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'SNAPWEAR',
                                      style: TextStyle(
                                        fontFamily: 'SnapSerif',
                                        fontSize: width * .084,
                                        letterSpacing: 1,
                                        color: const Color(0xFF053229),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Fashion near you. Delivered fast.',
                                      style: TextStyle(
                                        fontSize: width * .029,
                                        color: const Color(0xFF053229),
                                        decoration: TextDecoration.none,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
    ],
  );
}

class _ColourOpeningPainter extends CustomPainter {
  final List<ui.Image> images;
  final int palette;
  final double seconds;
  final bool reduced;
  _ColourOpeningPainter(this.images, this.palette, this.seconds, this.reduced);
  @override
  void paint(Canvas canvas, Size size) {
    if (images.length < 2) {
      return;
    }
    final atlas = images[0], garments = images[1];
    Rect tile(int col, int row) => Rect.fromLTWH(
      col * atlas.width / 2,
      row * atlas.height / 2,
      atlas.width / 2,
      atlas.height / 2,
    );
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawImageRect(
      atlas,
      tile(0, 0),
      Rect.fromLTWH(0, size.height * .27, size.width, size.height * .48),
      Paint()..filterQuality = FilterQuality.high,
    );
    if (!reduced) {
      for (var i = 0; i < 3; i++) {
        final t = ((seconds - [1.0, 1.6, 2.2][i]) / .55).clamp(0.0, 1.0);
        if (t <= 0 || t >= 1) {
          continue;
        }
        final drop = Curves.easeInOut.transform(t);
        final scale = t < .65 ? 1 - .15 * t / .65 : .85 - .61 * (t - .65) / .35;
        final w = size.width * (i == 1 ? .60 : .56);
        final h = size.height * (i == 1 ? .30 : .29);
        final center = Offset(
          size.width * .20,
          size.height * .25 + h / 2 + drop * h * .75,
        );
        final opacity =
            (t < .12
                    ? t / .12
                    : t > .9
                    ? (1 - t) / .1
                    : 1.0)
                .clamp(0.0, 1.0);
        canvas.drawImageRect(
          garments,
          Rect.fromLTWH(
            i * garments.width / 3,
            0,
            garments.width / 3,
            garments.height.toDouble(),
          ),
          Rect.fromCenter(center: center, width: w * scale, height: h * scale),
          Paint()
            ..filterQuality = FilterQuality.high
            ..color = Color.fromRGBO(255, 255, 255, opacity),
        );
      }
    }
    final arrival = Curves.easeOutCubic.transform(
      (seconds / .65).clamp(0.0, 1.0),
    );
    final departure = Curves.easeInCubic.transform(
      ((seconds - 3.16) / .89).clamp(0.0, 1.0),
    );
    final x = reduced ? 0.0 : size.width * 1.15 * (arrival - 1 + departure);
    final opening = Curves.easeInOut.transform(
      ((seconds - .7) / .25).clamp(0.0, 1.0),
    );
    final closing = Curves.easeInOut.transform(
      ((seconds - 2.8) / .25).clamp(0.0, 1.0),
    );
    final open = reduced ? 0.0 : opening * (1 - closing);
    final dest = Rect.fromLTWH(x, size.height * .47, size.width, size.width);
    for (var row = 0; row < 2; row++) {
      canvas.drawImageRect(
        atlas,
        tile(1, row),
        dest,
        Paint()
          ..filterQuality = FilterQuality.high
          ..color = Color.fromRGBO(255, 255, 255, row == 0 ? open : 1 - open),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ColourOpeningPainter old) =>
      old.seconds != seconds || old.images.length != images.length;
}

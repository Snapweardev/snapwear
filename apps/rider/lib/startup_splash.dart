import 'package:flutter/material.dart';

import 'colour_opening.dart';

/// Arctic opening shared by customer, retailer, admin, and rider apps.
class SnapWearOpening extends StatelessWidget {
  final Widget child;
  const SnapWearOpening({super.key, required this.child});
  @override
  Widget build(BuildContext context) => FourColourOpening(child: child);
}

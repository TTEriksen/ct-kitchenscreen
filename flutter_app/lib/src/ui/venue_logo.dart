import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../kitchen.dart';
import 'theme.dart';

/// The top-bar logo: the venue's own when one is chosen in settings,
/// otherwise CTpos. (The app icon and start screen always stay CTpos.)
class VenueLogo extends StatelessWidget {
  const VenueLogo({super.key, required this.kitchen, required this.height});
  final Kitchen kitchen;
  final double height;

  @override
  Widget build(BuildContext context) => logoImage(kitchen.venueLogo(K.p.dark), height);
}

Widget logoImage(Uint8List? bytes, double height) {
  final ctpos = Image.asset(K.logo, height: height, semanticLabel: 'CTpos');
  if (bytes == null) return ctpos;
  return ConstrainedBox(
    constraints: BoxConstraints(maxWidth: height * 5, maxHeight: height),
    child: Image.memory(
      bytes,
      height: height,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      semanticLabel: 'Logo',
      errorBuilder: (_, _, _) => ctpos,
    ),
  );
}

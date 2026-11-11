import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Displays the approved vector assets without decoding large 4K bitmaps.
class DytavaAsset extends StatelessWidget {
  const DytavaAsset(this.asset, {super.key, this.size = 24, this.label});

  final String asset;
  final double size;
  final String? label;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
    asset,
    width: size,
    height: size,
    fit: BoxFit.contain,
    semanticsLabel: label,
    excludeFromSemantics: label == null,
  );
}

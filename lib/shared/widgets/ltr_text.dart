import 'package:flutter/material.dart';

/// Forces left-to-right layout for Latin/number runs (phone, plate, etc.).
class LtrText extends StatelessWidget {
  const LtrText(
    this.data, {
    super.key,
    this.style,
    this.textAlign,
  });

  final String data;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Text(
        data,
        style: style,
        textAlign: textAlign,
      ),
    );
  }
}

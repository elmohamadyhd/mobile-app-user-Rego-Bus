import 'package:flutter/material.dart';

/// Scrollable form content with a bottom bar pinned to the screen edge.
///
/// Use with [Scaffold.resizeToAvoidBottomInset] set to `false` so the bottom
/// bar does not lift when the keyboard opens. The scroll area still receives
/// keyboard inset padding so focused fields can scroll above the keyboard.
class AuthPinnedBottomLayout extends StatelessWidget {
  const AuthPinnedBottomLayout({
    super.key,
    required this.scrollChild,
    required this.bottom,
    this.padding = EdgeInsets.zero,
    this.bottomPadding = EdgeInsets.zero,
  });

  final Widget scrollChild;
  final Widget bottom;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry bottomPadding;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: keyboardInset),
            child: Padding(padding: padding, child: scrollChild),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(padding: bottomPadding, child: bottom),
        ),
      ],
    );
  }
}

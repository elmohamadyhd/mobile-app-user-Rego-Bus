import 'package:flutter/material.dart';

import 'package:app_skeleton/core/theme/app_spacing.dart';

/// Standard page scaffold. Wraps [body] in padding and adds a consistent
/// [AppBar]. Pass [actions] or override [padding] as needed.
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.padding = AppSpacing.pagePadding,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.resizeToAvoidBottomInset,
  });

  final Widget body;
  final String? title;
  final List<Widget>? actions;
  final EdgeInsetsGeometry padding;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final bool? resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: title != null
          ? AppBar(title: Text(title!), actions: actions)
          : null,
      body: Padding(padding: padding, child: body),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
    );
  }
}

import 'package:flutter/material.dart';

/// Full-screen CMS page. Implemented in Task 4.
class PageDetailScreen extends StatelessWidget {
  const PageDetailScreen({super.key, required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(slug)),
      body: const SizedBox.shrink(),
    );
  }
}

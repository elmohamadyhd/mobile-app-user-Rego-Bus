import 'package:flutter/material.dart';

/// Placeholder for Task 10 — create/edit address form.
class AddressFormScreen extends StatelessWidget {
  const AddressFormScreen({super.key, this.addressId});

  final int? addressId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Form')),
      );
}

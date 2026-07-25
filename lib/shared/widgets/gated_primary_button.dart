import 'package:flutter/material.dart';

import 'package:safaria/shared/widgets/primary_button.dart';

/// [PrimaryButton] that looks disabled when [gated], but still reports
/// [onGateBlocked] so the caller can show a snackbar.
class GatedPrimaryButton extends StatelessWidget {
  const GatedPrimaryButton({
    super.key,
    required this.label,
    required this.gated,
    required this.onPressed,
    required this.onGateBlocked,
    this.loading = false,
  });

  final String label;
  final bool gated;
  final bool loading;
  final VoidCallback onPressed;
  final VoidCallback onGateBlocked;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return PrimaryButton(label: label, loading: true, onPressed: null);
    }
    if (!gated) {
      return PrimaryButton(label: label, onPressed: onPressed);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onGateBlocked,
      child: PrimaryButton(label: label, onPressed: null),
    );
  }
}

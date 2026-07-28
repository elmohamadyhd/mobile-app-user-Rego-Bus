import 'package:flutter/material.dart';

import 'package:safaria/shared/widgets/language_picker_sheet.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

/// Globe icon button that opens [showLanguagePickerSheet] on tap. Used on
/// the app's start screens (onboarding, login) to switch languages.
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(PhosphorIconsLight.translate, color: color),
      onPressed: () => showLanguagePickerSheet(context),
    );
  }
}

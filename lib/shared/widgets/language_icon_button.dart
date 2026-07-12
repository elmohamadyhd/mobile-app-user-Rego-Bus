import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/shared/widgets/language_picker_sheet.dart';

/// Globe icon button that opens [showLanguagePickerSheet] on tap. Used on
/// the app's start screens (onboarding, login) to switch languages.
class LanguageIconButton extends StatelessWidget {
  const LanguageIconButton({super.key, this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(AppIcons.language, color: color),
      onPressed: () => showLanguagePickerSheet(context),
    );
  }
}

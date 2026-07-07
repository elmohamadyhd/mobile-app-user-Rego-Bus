import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/l10n/app_localizations.dart';

/// Intercepts the system back button when the router cannot pop further.
///
/// When [onSingleBack] is set, the first back press runs it instead of the
/// exit snackbar (e.g. switch shell tab to Home). Otherwise the user must
/// press back twice within [kExitWindow] to leave via [SystemNavigator.pop].
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    this.onSingleBack,
    this.alwaysIntercept = false,
  });

  final Widget child;

  /// Optional first-back action. When provided, a single back press invokes
  /// this instead of starting the double-tap exit countdown.
  final VoidCallback? onSingleBack;

  /// When true, never delegate to the router pop stack — always run the
  /// double-back (or [onSingleBack]) handler. Used on auth screens that must
  /// not return to an in-app route underneath.
  final bool alwaysIntercept;

  static const kExitWindow = Duration(seconds: 2);

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit> {
  DateTime? _lastBackPress;

  void _onPopInvoked(bool didPop) {
    if (didPop) return;

    final onSingleBack = widget.onSingleBack;
    if (onSingleBack != null) {
      _lastBackPress = null;
      onSingleBack();
      return;
    }

    final now = DateTime.now();
    final withinWindow = _lastBackPress != null &&
        now.difference(_lastBackPress!) <= DoubleBackToExit.kExitWindow;

    if (!withinWindow) {
      _lastBackPress = now;
      final l10n = AppLocalizations.of(context);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l10n.pressBackAgainToExit)));
      return;
    }

    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final canPop =
        widget.alwaysIntercept ? false : GoRouter.of(context).canPop();
    return PopScope(
      canPop: canPop,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: widget.child,
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rego/core/network/api_exception.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/wallet/presentation/providers/wallet_providers.dart';
import 'package:rego/features/wallet/presentation/wallet_routes.dart';
import 'package:rego/features/wallet/presentation/widgets/wallet_app_bar.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class WalletTopUpScreen extends ConsumerStatefulWidget {
  const WalletTopUpScreen({super.key});

  @override
  ConsumerState<WalletTopUpScreen> createState() => _WalletTopUpScreenState();
}

class _WalletTopUpScreenState extends ConsumerState<WalletTopUpScreen> {
  static const _quickAmounts = [50, 100, 200, 500];

  final _controller = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int get _amount => int.tryParse(_controller.text) ?? 0;

  Future<void> _submit() async {
    final amount = _amount;
    if (amount <= 0 || _submitting) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final url = await ref.read(walletRepositoryProvider).charge(amount);
      if (!mounted) return;
      unawaited(context.push(WalletRoutes.pay, extra: url));
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final amount = _amount;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: WalletAppBar(title: l10n.walletTopUpTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.walletTopUpAmountLabel,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: AppTypography.h1,
                decoration: InputDecoration(
                  suffixText: 'EGP',
                  filled: true,
                  fillColor: AppColors.inputFill,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.input),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final quick in _quickAmounts)
                    ChoiceChip(
                      label: Text('$quick EGP'),
                      selected: amount == quick,
                      onSelected: (_) {
                        _controller.text = '$quick';
                        setState(() {});
                      },
                    ),
                ],
              ),
              if (_error != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error!,
                  style: AppTypography.body.copyWith(color: AppColors.error),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              PrimaryButton(
                label: amount > 0
                    ? l10n.walletTopUpSubmit(amount)
                    : l10n.walletTopUpInvalidAmount,
                loading: _submitting,
                onPressed: amount > 0 ? _submit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

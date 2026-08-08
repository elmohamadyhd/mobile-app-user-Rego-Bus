import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Lets the rider see and delete the travellers the app has kept.
///
/// These records hold names, birth dates, and national ID numbers. Storing
/// them without a way to clear them would leave identity data on the device
/// with no recourse, so this screen is part of the saved-travellers feature,
/// not an optional extra.
class SavedTravellersScreen extends ConsumerStatefulWidget {
  const SavedTravellersScreen({super.key});

  @override
  ConsumerState<SavedTravellersScreen> createState() =>
      _SavedTravellersScreenState();
}

class _SavedTravellersScreenState extends ConsumerState<SavedTravellersScreen> {
  List<FlightPassengerDraft> _travellers = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final all = await ref.read(flightSavedTravellersStoreProvider).read();
    if (!mounted) return;
    setState(() {
      _travellers = all;
      _loading = false;
    });
  }

  Future<bool> _confirm() async {
    final l10n = AppLocalizations.of(context);
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(l10n.savedTravellersConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.savedTravellersCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.savedTravellersDelete,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  /// Only the last four digits are shown — enough for the rider to tell two
  /// records apart, without printing a full national ID on screen.
  String _maskedDocument(String? document) {
    final value = document?.trim() ?? '';
    if (value.length <= 4) return value;
    return '•••• ${value.substring(value.length - 4)}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: BookingAppBar(
        title: l10n.savedTravellersTitle,
        action: _travellers.isEmpty
            ? null
            : TextButton(
                onPressed: () async {
                  if (!await _confirm()) return;
                  await ref.read(flightSavedTravellersStoreProvider).clear();
                  await _reload();
                },
                child: Text(
                  l10n.savedTravellersDeleteAll,
                  style: AppTypography.caption
                      .copyWith(color: AppColors.error),
                ),
              ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _travellers.isEmpty
              ? Center(
                  child: Text(
                    l10n.savedTravellersEmpty,
                    style: AppTypography.body
                        .copyWith(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  itemCount: _travellers.length,
                  itemBuilder: (context, i) {
                    final traveller = _travellers[i];
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        [traveller.firstName, traveller.lastName]
                            .whereType<String>()
                            .join(' '),
                        style: AppTypography.body,
                      ),
                      subtitle: Text(
                        _maskedDocument(traveller.documentNumber),
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          PhosphorIconsLight.trash,
                          color: AppColors.error,
                        ),
                        onPressed: () async {
                          final id = traveller.savedId;
                          if (id == null || !await _confirm()) return;
                          await ref
                              .read(flightSavedTravellersStoreProvider)
                              .delete(id);
                          await _reload();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/features/flight/domain/entities/flight_country.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/l10n/app_localizations.dart';

/// Country picker backed by `GET /countries`.
///
/// The auth screens ship a hardcoded dial-code list with no ISO codes, which
/// cannot serve the passenger form — the provider needs a country code, not a
/// flag and a phone prefix.
class FlightCountryField extends ConsumerWidget {
  const FlightCountryField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.useIso2 = false,
  });

  /// The stored value, in whichever ISO width the caller uses.
  final String? value;
  final String label;
  final ValueChanged<FlightCountry> onChanged;
  final String? errorText;

  /// `nationalityCode`/`residenceCode` take [FlightCountry.passengerCode];
  /// `address.countryCode` always takes `iso2`. Set true for the address
  /// field so selection matches the right width.
  final bool useIso2;

  String _codeOf(FlightCountry country) =>
      useIso2 ? country.iso2 : country.passengerCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countries = ref.watch(flightCountriesProvider);

    return countries.when(
      loading: () => _Shell(label: label, child: const Text('…')),
      error: (_, __) => _Shell(label: label, child: const Text('—')),
      data: (list) {
        FlightCountry? selected;
        for (final country in list) {
          if (_codeOf(country) == value) selected = country;
        }
        return _Shell(
          label: label,
          errorText: errorText,
          onTap: () async {
            final picked = await showModalBottomSheet<FlightCountry>(
              context: context,
              isScrollControlled: true,
              backgroundColor: AppColors.bgElevated,
              builder: (_) => _CountrySheet(countries: list),
            );
            if (picked != null) onChanged(picked);
          },
          child: Text(
            selected?.name ?? '',
            style: AppTypography.body,
          ),
        );
      },
    );
  }
}

class _Shell extends StatelessWidget {
  const _Shell({
    required this.label,
    required this.child,
    this.onTap,
    this.errorText,
  });

  final String label;
  final Widget child;
  final VoidCallback? onTap;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.input),
              border: Border.all(
                color: errorText == null ? AppColors.hairline : AppColors.error,
              ),
            ),
            child: child,
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

class _CountrySheet extends StatefulWidget {
  const _CountrySheet({required this.countries});

  final List<FlightCountry> countries;

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final needle = _query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? widget.countries
        : widget.countries
            .where((c) =>
                c.name.toLowerCase().contains(needle) ||
                c.iso2.toLowerCase().startsWith(needle) ||
                c.iso3.toLowerCase().startsWith(needle))
            .toList();

    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: AppSpacing.lg,
        end: AppSpacing.lg,
        top: AppSpacing.lg,
        bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            autofocus: true,
            decoration: InputDecoration(hintText: l10n.flightCountrySearch),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: AppSpacing.md),
          if (matches.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Text(
                l10n.flightCountryEmpty,
                style: AppTypography.body.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: matches.length,
                itemBuilder: (context, i) => ListTile(
                  title: Text(matches[i].name, style: AppTypography.body),
                  onTap: () => Navigator.of(context).pop(matches[i]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/date_formatting.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_country_field.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/primary_button.dart';

/// One traveller, full screen. Reached from [FlightPassengersScreen] via
/// `FlightRoutes.passengerForm`.
class FlightPassengerFormScreen extends ConsumerStatefulWidget {
  const FlightPassengerFormScreen({super.key, required this.index});

  final int index;

  @override
  ConsumerState<FlightPassengerFormScreen> createState() =>
      _FlightPassengerFormScreenState();
}

class _FlightPassengerFormScreenState
    extends ConsumerState<FlightPassengerFormScreen> {
  late FlightPassengerDraft _draft;
  bool _saveForNextTime = false;

  @override
  void initState() {
    super.initState();
    final drafts = ref.read(flightBookingProvider).passengerDrafts;
    _draft = widget.index < drafts.length
        ? drafts[widget.index]
        : const FlightPassengerDraft(type: FlightPassengerType.adult);
  }

  /// Departure is the first leg's date — the reference point for age, since
  /// a child who turns 12 before the flight travels on an adult fare.
  DateTime _departureDate() {
    final params = ref.read(flightBookingProvider).searchParams;
    return params?.legs.first.date ?? DateTime.now();
  }

  Future<void> _save() async {
    ref
        .read(flightBookingProvider.notifier)
        .updatePassengerDraft(widget.index, _draft);
    if (_saveForNextTime) {
      await ref.read(flightSavedTravellersStoreProvider).save(_draft);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errors =
        ref.watch(flightBookingProvider).passengerErrors[widget.index] ?? {};
    final departure = _departureDate();
    final mismatch =
        flightPassengerTypeMismatch(_draft, departureDate: departure);

    return Scaffold(
      appBar: BookingAppBar(title: l10n.flightPassengersTitle),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _SavedTravellerChips(
            onPick: (picked) => setState(() {
              _draft = picked.copyWith(
                type: _draft.type,
                savedId: picked.savedId,
              );
            }),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _draft.title,
                  decoration: InputDecoration(labelText: l10n.flightFieldTitle),
                  items: [
                    DropdownMenuItem(
                      value: 'MR',
                      child: Text(l10n.flightTitleMr),
                    ),
                    DropdownMenuItem(
                      value: 'MRS',
                      child: Text(l10n.flightTitleMrs),
                    ),
                    DropdownMenuItem(
                      value: 'MS',
                      child: Text(l10n.flightTitleMs),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _draft = _draft.copyWith(title: value)),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _draft.gender,
                  decoration:
                      InputDecoration(labelText: l10n.flightFieldGender),
                  items: [
                    DropdownMenuItem(
                      value: 'M',
                      child: Text(l10n.flightGenderMale),
                    ),
                    DropdownMenuItem(
                      value: 'F',
                      child: Text(l10n.flightGenderFemale),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    // Derive the title from gender only while the rider has
                    // not chosen one — never overwrite their choice.
                    final title = _draft.title ?? (value == 'F' ? 'MRS' : 'MR');
                    _draft = _draft.copyWith(gender: value, title: title);
                  }),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.flightNameAsPassport,
            style:
                AppTypography.caption.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          _LatinField(
            label: l10n.flightFirstName,
            value: _draft.firstName,
            errorText: errors['firstName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(firstName: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LatinField(
            label: l10n.flightMiddleName,
            value: _draft.middleName,
            errorText: errors['middleName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(middleName: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          _LatinField(
            label: l10n.flightLastName,
            value: _draft.lastName,
            errorText: errors['lastName'],
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(lastName: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _draft.birthDate ?? DateTime(1990),
                firstDate: DateTime(1920),
                lastDate: departure,
              );
              if (picked != null) {
                setState(() => _draft = _draft.copyWith(birthDate: picked));
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: l10n.flightFieldBirthDate,
                errorText: errors['birthDate'],
              ),
              child: Text(
                _draft.birthDate == null ? '' : toIsoDate(_draft.birthDate!),
                style: AppTypography.body,
              ),
            ),
          ),
          if (mismatch != null)
            Padding(
              padding: const EdgeInsetsDirectional.only(top: AppSpacing.xs),
              child: Text(
                l10n.flightTypeMismatch,
                style: AppTypography.caption.copyWith(color: AppColors.warning),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: _draft.documentNumber,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightFieldDocumentNumber,
              errorText: errors['documentNumber'] ??
                  ((_draft.documentNumber ?? '').isNotEmpty &&
                          _draft.documentNumber!.trim().length != 14
                      ? l10n.flightNidLength
                      : null),
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(documentNumber: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          FlightCountryField(
            label: l10n.flightFieldNationality,
            value: _draft.nationalityCode,
            errorText: errors['nationalityCountryCode'],
            onChanged: (country) => setState(
              () => _draft =
                  _draft.copyWith(nationalityCode: country.passengerCode),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          FlightCountryField(
            label: l10n.flightFieldResidence,
            value: _draft.residenceCode,
            errorText: errors['residenceCountryCode'],
            onChanged: (country) => setState(
              () => _draft =
                  _draft.copyWith(residenceCode: country.passengerCode),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            l10n.flightFieldAddressCountry,
            style: AppTypography.body,
          ),
          const SizedBox(height: AppSpacing.sm),
          FlightCountryField(
            label: l10n.flightFieldAddressCountry,
            value: _draft.addressCountryCode,
            useIso2: true,
            errorText: errors['address.countryCode'],
            onChanged: (country) => setState(
              () => _draft = _draft.copyWith(addressCountryCode: country.iso2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            initialValue: _draft.addressCityCode,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightFieldAddressCity,
              errorText: errors['address.cityCode'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(addressCityCode: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.addressLine1,
            decoration: InputDecoration(
              labelText: l10n.flightFieldAddressLine1,
              errorText: errors['address.line1'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(addressLine1: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.addressLine2,
            decoration: InputDecoration(
              labelText: l10n.flightFieldAddressLine2,
              errorText: errors['address.line2'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(addressLine2: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.email,
            keyboardType: TextInputType.emailAddress,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightContactEmail,
              errorText: errors['email'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(email: v)),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            initialValue: _draft.phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(
              labelText: l10n.flightContactPhone,
              errorText: errors['phone'],
            ),
            onChanged: (v) =>
                setState(() => _draft = _draft.copyWith(phone: v)),
          ),
          const SizedBox(height: AppSpacing.md),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: _saveForNextTime,
            onChanged: (value) =>
                setState(() => _saveForNextTime = value ?? false),
            title: Text(
              l10n.flightSaveForNextTime,
              style: AppTypography.body,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(label: l10n.flightSave, onPressed: _save),
        ],
      ),
    );
  }
}

/// Name fields stay Latin and left-to-right inside an otherwise RTL app —
/// carriers match the name to the travel document, and an Arabic name is
/// rejected at the gate.
class _LatinField extends StatelessWidget {
  const _LatinField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final String? value;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.left,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(labelText: label, errorText: errorText),
      onChanged: onChanged,
    );
  }
}

/// Tappable chips for previously saved travellers. Renders nothing when the
/// store is empty, so a first-time rider sees no dead affordance.
class _SavedTravellerChips extends ConsumerWidget {
  const _SavedTravellerChips({required this.onPick});

  final ValueChanged<FlightPassengerDraft> onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return FutureBuilder<List<FlightPassengerDraft>>(
      future: ref.read(flightSavedTravellersStoreProvider).read(),
      builder: (context, snapshot) {
        final saved = snapshot.data ?? const <FlightPassengerDraft>[];
        if (saved.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.flightSavedTravellers,
              style: AppTypography.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              children: [
                for (final traveller in saved)
                  ActionChip(
                    label: Text(
                      [traveller.firstName, traveller.lastName]
                          .whereType<String>()
                          .join(' '),
                    ),
                    onPressed: () => onPick(traveller),
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

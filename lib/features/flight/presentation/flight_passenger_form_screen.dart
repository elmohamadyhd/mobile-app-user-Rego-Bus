import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/bus/presentation/widgets/booking_app_bar.dart';
import 'package:safaria/features/flight/data/flight_saved_travellers_store.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_counts.dart';
import 'package:safaria/features/flight/domain/entities/flight_passenger_draft.dart';
import 'package:safaria/features/flight/domain/utils/flight_passenger_validation.dart';
import 'package:safaria/features/flight/presentation/providers/flight_booking_providers.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_country_field.dart';
import 'package:safaria/features/flight/presentation/widgets/flight_form_controls.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/widgets/ltr_icon.dart';
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
  int _formEpoch = 0;

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

  void _applySaved(FlightPassengerDraft picked) {
    setState(() {
      _draft = picked.copyWith(
        type: _draft.type,
        savedId: picked.savedId,
      );
      _formEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final errors =
        ref.watch(flightBookingProvider).passengerErrors[widget.index] ?? {};
    final departure = _departureDate();
    final mismatch =
        flightPassengerTypeMismatch(_draft, departureDate: departure);
    final locale = Localizations.localeOf(context).toString();
    final sideBySide = !context.isCompact;

    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: BookingAppBar(title: l10n.flightPassengersTitle),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: AppBreakpoints.maxContentWidth,
            ),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    children: [
                      _SavedTravellerChips(onPick: _applySaved),
                      KeyedSubtree(
                        key: ValueKey(_formEpoch),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            FlightSectionHeader(l10n.flightSectionIdentity),
                            _pairOrStack(
                              sideBySide: sideBySide,
                              first: _dropdown<String>(
                                label: l10n.flightFieldTitle,
                                value: _draft.title,
                                hint: l10n.flightSelectPlaceholder,
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
                                onChanged: (value) => setState(
                                  () => _draft = _draft.copyWith(title: value),
                                ),
                              ),
                              second: _dropdown<String>(
                                label: l10n.flightFieldGender,
                                value: _draft.gender,
                                hint: l10n.flightSelectPlaceholder,
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
                                  final title = _draft.title ??
                                      (value == 'F' ? 'MRS' : 'MR');
                                  _draft = _draft.copyWith(
                                    gender: value,
                                    title: title,
                                  );
                                }),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Text(
                              l10n.flightNameAsPassport,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            _LatinField(
                              label: l10n.flightFirstName,
                              value: _draft.firstName,
                              errorText: errors['firstName'],
                              onChanged: (v) => setState(
                                () => _draft = _draft.copyWith(firstName: v),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _LatinField(
                              label: l10n.flightMiddleName,
                              value: _draft.middleName,
                              errorText: errors['middleName'],
                              onChanged: (v) => setState(
                                () => _draft = _draft.copyWith(middleName: v),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _LatinField(
                              label: l10n.flightLastName,
                              value: _draft.lastName,
                              errorText: errors['lastName'],
                              onChanged: (v) => setState(
                                () => _draft = _draft.copyWith(lastName: v),
                              ),
                            ),
                            FlightSectionHeader(l10n.flightSectionDocument),
                            FlightFormPicker(
                              label: l10n.flightFieldBirthDate,
                              valueText: _draft.birthDate == null
                                  ? null
                                  : DateFormat.yMMMd(locale)
                                      .format(_draft.birthDate!),
                              hintText: l10n.flightSelectDate,
                              icon: PhosphorIconsLight.calendarBlank,
                              errorText: errors['birthDate'],
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _draft.birthDate ?? DateTime(1990),
                                  firstDate: DateTime(1920),
                                  lastDate: departure,
                                );
                                if (picked != null) {
                                  setState(
                                    () => _draft =
                                        _draft.copyWith(birthDate: picked),
                                  );
                                }
                              },
                            ),
                            if (mismatch != null)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  top: AppSpacing.xs,
                                ),
                                child: Text(
                                  l10n.flightTypeMismatch,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.secondaryDeep,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            const SizedBox(height: AppSpacing.md),
                            _labeledField(
                              label: l10n.flightFieldDocumentNumber,
                              child: TextFormField(
                                initialValue: _draft.documentNumber,
                                keyboardType: TextInputType.number,
                                textDirection: TextDirection.ltr,
                                decoration: flightFormDecoration(
                                  errorText: errors['documentNumber'] ??
                                      ((_draft.documentNumber ?? '')
                                                  .isNotEmpty &&
                                              _draft.documentNumber!
                                                      .trim()
                                                      .length !=
                                                  14
                                          ? l10n.flightNidLength
                                          : null),
                                ),
                                onChanged: (v) => setState(
                                  () => _draft =
                                      _draft.copyWith(documentNumber: v),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FlightCountryField(
                              label: l10n.flightFieldNationality,
                              value: _draft.nationalityCode,
                              errorText: errors['nationalityCountryCode'],
                              onChanged: (country) => setState(
                                () => _draft = _draft.copyWith(
                                  nationalityCode: country.passengerCode,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            FlightCountryField(
                              label: l10n.flightFieldResidence,
                              value: _draft.residenceCode,
                              errorText: errors['residenceCountryCode'],
                              onChanged: (country) => setState(
                                () => _draft = _draft.copyWith(
                                  residenceCode: country.passengerCode,
                                ),
                              ),
                            ),
                            FlightSectionHeader(l10n.flightSectionAddress),
                            FlightCountryField(
                              label: l10n.flightFieldAddressCountry,
                              value: _draft.addressCountryCode,
                              useIso2: true,
                              errorText: errors['address.countryCode'],
                              onChanged: (country) => setState(
                                () => _draft = _draft.copyWith(
                                  addressCountryCode: country.iso2,
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _labeledField(
                              label: l10n.flightFieldAddressCity,
                              child: TextFormField(
                                initialValue: _draft.addressCityCode,
                                textDirection: TextDirection.ltr,
                                decoration: flightFormDecoration(
                                  errorText: errors['address.cityCode'],
                                ),
                                onChanged: (v) => setState(
                                  () => _draft =
                                      _draft.copyWith(addressCityCode: v),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _labeledField(
                              label: l10n.flightFieldAddressLine1,
                              child: TextFormField(
                                initialValue: _draft.addressLine1,
                                decoration: flightFormDecoration(
                                  errorText: errors['address.line1'],
                                ),
                                onChanged: (v) => setState(
                                  () =>
                                      _draft = _draft.copyWith(addressLine1: v),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _labeledField(
                              label: l10n.flightFieldAddressLine2,
                              child: TextFormField(
                                initialValue: _draft.addressLine2,
                                decoration: flightFormDecoration(
                                  errorText: errors['address.line2'],
                                ),
                                onChanged: (v) => setState(
                                  () =>
                                      _draft = _draft.copyWith(addressLine2: v),
                                ),
                              ),
                            ),
                            FlightSectionHeader(l10n.flightSectionContact),
                            _labeledField(
                              label: l10n.flightContactEmail,
                              child: TextFormField(
                                initialValue: _draft.email,
                                keyboardType: TextInputType.emailAddress,
                                textDirection: TextDirection.ltr,
                                decoration: flightFormDecoration(
                                  errorText: errors['email'],
                                ),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(email: v),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                            _labeledField(
                              label: l10n.flightContactPhone,
                              child: TextFormField(
                                initialValue: _draft.phone,
                                keyboardType: TextInputType.phone,
                                textDirection: TextDirection.ltr,
                                decoration: flightFormDecoration(
                                  errorText: errors['phone'],
                                ),
                                onChanged: (v) => setState(
                                  () => _draft = _draft.copyWith(phone: v),
                                ),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              value: _saveForNextTime,
                              onChanged: (value) => setState(
                                () => _saveForNextTime = value ?? false,
                              ),
                              title: Text(
                                l10n.flightSaveForNextTime,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.lg,
                    AppSpacing.sm,
                    AppSpacing.lg,
                    AppSpacing.lg,
                  ),
                  child: PrimaryButton(
                    label: l10n.flightSave,
                    onPressed: _save,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pairOrStack({
    required bool sideBySide,
    required Widget first,
    required Widget second,
  }) {
    if (!sideBySide) {
      return Column(
        children: [
          first,
          const SizedBox(height: AppSpacing.md),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: second),
      ],
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required String hint,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightFieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: value,
          isExpanded: true,
          decoration: flightFormDecoration(),
          icon: const LtrIcon(
            PhosphorIconsLight.caretDown,
            size: 16,
            color: AppColors.textSecondary,
          ),
          hint: Text(hint),
          items: items,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _labeledField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightFieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        child,
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FlightFieldLabel(label),
        const SizedBox(height: AppSpacing.xs),
        TextFormField(
          initialValue: value,
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.left,
          textCapitalization: TextCapitalization.words,
          decoration: flightFormDecoration(errorText: errorText),
          onChanged: onChanged,
        ),
      ],
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
            FlightFieldLabel(l10n.flightSavedTravellers),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:safaria/core/network/api_exception.dart';
import 'package:safaria/core/theme/app_colors.dart';
import 'package:safaria/core/theme/app_spacing.dart';
import 'package:safaria/core/theme/app_typography.dart';
import 'package:safaria/core/utils/responsive.dart';
import 'package:safaria/features/addresses/domain/entities/saved_address.dart';
import 'package:safaria/features/addresses/presentation/providers/addresses_providers.dart';
import 'package:safaria/features/addresses/presentation/widgets/addresses_app_bar.dart';
import 'package:safaria/l10n/app_localizations.dart';
import 'package:safaria/shared/models/map_place.dart';
import 'package:safaria/shared/widgets/map_place_picker_args.dart';
import 'package:safaria/shared/widgets/place_picker_routes.dart';
import 'package:safaria/shared/widgets/primary_button.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.addressId});

  final int? addressId;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();

  MapLocation? _location;
  String? _locationError;
  bool _submitting = false;
  bool _initialized = false;

  bool get _isEdit => widget.addressId != null;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateFromAddress(SavedAddress address) {
    _nameController.text = address.name;
    _phoneController.text = address.phone ?? '';
    _notesController.text = address.notes ?? '';
    _location = address.mapLocation;
    _initialized = true;
  }

  SavedAddress? _findAddress(Iterable<SavedAddress> items) {
    final id = widget.addressId;
    if (id == null) return null;
    for (final item in items) {
      if (item.id == id) return item;
    }
    return null;
  }

  Future<void> _pickLocation(AppLocalizations l10n) async {
    final picked = await context.push<MapPlace>(
      PlacePickerRoutes.picker,
      extra: MapPlacePickerArgs(
        title: l10n.addressFormLocationLabel,
        initial: _location == null
            ? null
            : MapPlace(
                latitude: _location!.latitude,
                longitude: _location!.longitude,
                label: _location!.addressName,
              ),
        showUseMyLocation: true,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _location = MapLocation(
        latitude: picked.latitude,
        longitude: picked.longitude,
        addressName: picked.label,
      );
      _locationError = null;
    });
  }

  Future<void> _save(AppLocalizations l10n) async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    if (_location == null) {
      setState(() => _locationError = l10n.addressFormLocationRequired);
      return;
    }

    setState(() {
      _locationError = null;
      _submitting = true;
    });

    final phone = _phoneController.text.trim();
    final notes = _notesController.text.trim();
    final repo = ref.read(addressesRepositoryProvider);

    try {
      if (_isEdit) {
        await repo.update(
          id: widget.addressId!,
          name: _nameController.text.trim(),
          mapLocation: _location!,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
        );
      } else {
        await repo.create(
          name: _nameController.text.trim(),
          mapLocation: _location!,
          phone: phone.isEmpty ? null : phone,
          notes: notes.isEmpty ? null : notes,
        );
      }

      if (!mounted) return;
      ref.invalidate(addressesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addressFormSaved)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _confirmDelete(AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        title: Text(l10n.addressFormDeleteTitle, style: AppTypography.h2),
        content: Text(
          l10n.addressFormDeleteMessage,
          style: AppTypography.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              l10n.profileLogoutCancel,
              style: AppTypography.title.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              l10n.addressFormDeleteConfirm,
              style: AppTypography.title.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await ref.read(addressesProvider.notifier).delete(widget.addressId!);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addressFormDeleted)),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (_isEdit && !_initialized) {
      final addressesAsync = ref.watch(addressesProvider);
      return addressesAsync.when(
        loading: () => _loadingScaffold(l10n),
        error: (_, __) => _errorScaffold(l10n),
        data: (page) {
          final address = _findAddress(page.items);
          if (address == null) {
            return _notFoundScaffold(l10n);
          }

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || _initialized) return;
            setState(() => _populateFromAddress(address));
          });

          return _loadingScaffold(l10n);
        },
      );
    }

    return _formScaffold(l10n);
  }

  Widget _loadingScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AddressesAppBar(
        title: _isEdit ? l10n.addressFormEditTitle : l10n.addressFormCreateTitle,
      ),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _errorScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AddressesAppBar(
        title: l10n.addressFormEditTitle,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.addressesError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(addressesProvider.notifier).refresh(),
              child: Text(l10n.addressesRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notFoundScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AddressesAppBar(
        title: l10n.addressFormEditTitle,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              l10n.addressesError,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: () => ref.read(addressesProvider.notifier).refresh(),
              child: Text(l10n.addressesRetry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formScaffold(AppLocalizations l10n) {
    return Scaffold(
      backgroundColor: AppColors.bgBase,
      appBar: AddressesAppBar(
        title: _isEdit ? l10n.addressFormEditTitle : l10n.addressFormCreateTitle,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = context.isExpanded
                ? AppBreakpoints.maxContentWidth
                : constraints.maxWidth;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _FieldLabel(text: l10n.addressFormNameLabel),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            hintText: l10n.addressFormNameHint,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return l10n.addressFormNameRequired;
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel(text: l10n.addressFormLocationLabel),
                        const SizedBox(height: AppSpacing.xs),
                        _LocationField(
                          label: _location?.addressName ??
                              l10n.addressFormLocationPlaceholder,
                          hasLocation: _location != null,
                          errorText: _locationError,
                          onTap: () => _pickLocation(l10n),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel(text: l10n.addressFormPhoneLabel),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _FieldLabel(text: l10n.addressFormNotesLabel),
                        const SizedBox(height: AppSpacing.xs),
                        TextFormField(
                          controller: _notesController,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          minLines: 3,
                          maxLines: 5,
                          decoration: const InputDecoration(),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        PrimaryButton(
                          label: l10n.addressFormSave,
                          loading: _submitting,
                          onPressed: _submitting ? null : () => _save(l10n),
                        ),
                        if (_isEdit) ...[
                          const SizedBox(height: AppSpacing.md),
                          TextButton(
                            onPressed: _submitting
                                ? null
                                : () => _confirmDelete(l10n),
                            child: Text(
                              l10n.addressFormDelete,
                              style: AppTypography.title.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LocationField extends StatelessWidget {
  const _LocationField({
    required this.label,
    required this.hasLocation,
    required this.onTap,
    this.errorText,
  });

  final String label;
  final bool hasLocation;
  final String? errorText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          color: AppColors.inputFill,
          borderRadius: BorderRadius.circular(AppRadius.input),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.input),
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.input),
                border: Border.all(
                  color: hasError ? AppColors.error : AppColors.hairline,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsLight.mapPin,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body.copyWith(
                        color: hasLocation
                            ? AppColors.textPrimary
                            : AppColors.textMuted,
                      ),
                    ),
                  ),
                  Transform.flip(
                    flipX: Directionality.of(context) == TextDirection.rtl,
                    child: const Icon(
                      PhosphorIconsLight.caretRight,
                      size: 18,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsetsDirectional.only(
              top: AppSpacing.xs,
              start: AppSpacing.xs,
            ),
            child: Text(
              errorText!,
              style: AppTypography.caption.copyWith(color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

// lib/features/bus/presentation/eticket_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import 'package:rego/core/router/app_router.dart';
import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/core/utils/responsive.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/features/bus/domain/entities/bus_ticket.dart';
import 'package:rego/features/bus/presentation/providers/bus_booking_providers.dart';
import 'package:rego/features/bus/presentation/widgets/operator_avatar.dart';
import 'package:rego/features/bus/presentation/widgets/ticket_border.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/providers/ticket_pdf_providers.dart';
import 'package:rego/shared/widgets/primary_button.dart';

class BusTicketScreen extends ConsumerWidget {
  const BusTicketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(busBookingProvider.select((s) => s.ticket));

    if (ticket == null) {
      return const Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: AppColors.heroGradient),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    void goHome() {
      context.go(AppRoutes.home);
      Future.microtask(() => ref.read(busBookingProvider.notifier).reset());
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        goHome();
      },
      child: Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: const BoxDecoration(gradient: AppColors.heroGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsetsDirectional.only(
                  bottom: AppSpacing.lg,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppBreakpoints.maxContentWidth,
                      minHeight: MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical,
                    ),
                    child: Column(
                      children: [
                        const SizedBox(height: AppSpacing.lg),
                        const _HeroSection(),
                        Transform.translate(
                          offset: const Offset(0, -AppSpacing.lg),
                          child: Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                            child: _BoardingPassCard(ticket: ticket),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: _ActionButtons(ticket: ticket),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Padding(
                          padding: const EdgeInsetsDirectional.symmetric(
                            horizontal: AppSpacing.lg,
                          ),
                          child: PrimaryButton(
                            label: AppLocalizations.of(context).eTicketBackHome,
                            onPressed: goHome,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero section ─────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.success,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: AppColors.success,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.checkCircle,
                  color: AppColors.onHero,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.eTicketConfirmed,
            textAlign: TextAlign.center,
            style: AppTypography.h1.copyWith(color: AppColors.onHero),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            l10n.eTicketSubtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.onHero.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

// ── Boarding pass card ────────────────────────────────────────────────────────

class _BoardingPassCard extends StatelessWidget {
  const _BoardingPassCard({required this.ticket});

  final BusTicket ticket;

  static const double _priceStubHeight = 88;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final trip = ticket.trip;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final dateLabel = DateFormat.yMMMd(locale).format(trip.dateTime);
    final seatsJoined = ticket.seats.isNotEmpty ? ticket.seats.join(', ') : '-';
    final departTime = _stopTimeLabel(ticket.fromStop, trip.departTime);
    final arriveTime = _stopTimeLabel(ticket.toStop, trip.arriveTime);

    const shape = TicketBorder(
      radius: AppRadius.card,
      notchRadius: 12,
      notchOffsetFromBottom: _priceStubHeight,
      dashColor: AppColors.hairline,
    );

    return Material(
      color: AppColors.bgCard,
      shape: shape,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.35),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                OperatorAvatar(trip: trip, size: 38),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: trip.operatorName,
                              style: AppTypography.title.copyWith(
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            if (trip.serviceClass.trim().isNotEmpty)
                              TextSpan(
                                text: '  ·  ${trip.serviceClass}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.eTicketBoardingPass,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: _RouteTimeline(
              departTime: departTime,
              arriveTime: arriveTime,
              fromName: ticket.fromStop.name,
              toName: ticket.toStop.name,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetaCell(
                    label: l10n.eTicketDate,
                    value: dateLabel,
                  ),
                ),
                Expanded(
                  child: _MetaCell(
                    label: l10n.eTicketSeats,
                    value: seatsJoined,
                    align: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: _MetaCell(
                    label: l10n.eTicketRef,
                    value: ticket.bookingRef,
                    align: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: _priceStubHeight,
            child: Center(
              child: _PriceStub(total: ticket.total),
            ),
          ),
        ],
      ),
    );
  }

  static String _stopTimeLabel(BusStop stop, DateTime fallback) {
    final dt = stop.arrivalAt ?? fallback;
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _RouteTimeline extends StatelessWidget {
  const _RouteTimeline({
    required this.departTime,
    required this.arriveTime,
    required this.fromName,
    required this.toName,
  });

  final String departTime;
  final String arriveTime;
  final String fromName;
  final String toName;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: _TimeCell(
                time: departTime,
                alignment: AlignmentDirectional.centerStart,
              ),
            ),
            const Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                child: _ConnectorLine(),
              ),
            ),
            Expanded(
              child: _TimeCell(
                time: arriveTime,
                alignment: AlignmentDirectional.centerEnd,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Text(
                fromName,
                textAlign: TextAlign.start,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const Expanded(flex: 2, child: SizedBox.shrink()),
            Expanded(
              child: Text(
                toName,
                textAlign: TextAlign.end,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({required this.time, required this.alignment});

  final String time;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        time,
        style: AppTypography.h2.copyWith(
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  const _ConnectorLine();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          AppIcons.bus,
          color: AppColors.primary,
          size: 20,
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            _dot(AppColors.primary),
            const Expanded(
                child: Divider(color: AppColors.hairline, height: 1)),
            _dot(AppColors.secondary),
          ],
        ),
      ],
    );
  }

  Widget _dot(Color color) => Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}

class _MetaCell extends StatelessWidget {
  const _MetaCell({
    required this.label,
    required this.value,
    this.align = TextAlign.start,
  });

  final String label;
  final String value;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: align == TextAlign.end
          ? CrossAxisAlignment.end
          : align == TextAlign.center
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: align,
          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: align,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.body.copyWith(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _PriceStub extends StatelessWidget {
  const _PriceStub({required this.total});

  final String total;

  @override
  Widget build(BuildContext context) {
    if (total.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      total,
      style: AppTypography.h2.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ── Action buttons row ────────────────────────────────────────────────────────

class _ActionButtons extends ConsumerStatefulWidget {
  const _ActionButtons({required this.ticket});

  final BusTicket ticket;

  @override
  ConsumerState<_ActionButtons> createState() => _ActionButtonsState();
}

class _ActionButtonsState extends ConsumerState<_ActionButtons> {
  bool _downloading = false;
  bool _sharing = false;

  Future<void> _downloadTicket() async {
    if (_downloading || _sharing) return;
    setState(() => _downloading = true);
    try {
      await downloadTicketPdf(
        ref,
        context,
        invoiceUrl: widget.ticket.invoiceUrl ?? '',
        bookingRef: widget.ticket.bookingRef,
      );
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _shareTicket() async {
    if (_downloading || _sharing) return;
    setState(() => _sharing = true);
    try {
      await shareTicketPdf(
        ref,
        context,
        invoiceUrl: widget.ticket.invoiceUrl ?? '',
        bookingRef: widget.ticket.bookingRef,
      );
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final busy = _downloading || _sharing;

    return Row(
      children: [
        Expanded(
          child: _GradientActionButton(
            onPressed: busy ? null : _downloadTicket,
            icon: AppIcons.download,
            label: l10n.eTicketDownload,
            filled: true,
            loading: _downloading,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: _GradientActionButton(
            onPressed: busy ? null : _shareTicket,
            icon: AppIcons.share,
            label: l10n.eTicketShare,
            filled: false,
            loading: _sharing,
          ),
        ),
      ],
    );
  }
}

class _GradientActionButton extends StatelessWidget {
  const _GradientActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
    required this.filled,
    this.loading = false,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;
  final bool filled;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final fg = filled ? AppColors.primary : AppColors.onHero;
    final bg = filled ? AppColors.onHero : Colors.transparent;
    final border = filled
        ? BorderSide.none
        : BorderSide(color: AppColors.onHero.withValues(alpha: 0.35));

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        onTap: loading ? null : onPressed,
        borderRadius: BorderRadius.circular(AppRadius.button),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.button),
            border: Border.fromBorderSide(border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: fg,
                    ),
                  )
                else
                  Icon(icon, color: fg, size: 18),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    label,
                    style: AppTypography.title.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

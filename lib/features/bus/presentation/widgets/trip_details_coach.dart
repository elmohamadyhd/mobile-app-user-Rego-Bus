import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:rego/core/storage/secure_storage.dart';
import 'package:rego/l10n/app_localizations.dart';
import 'package:rego/shared/widgets/coach_mark_overlay.dart';

/// Whether a trip-details coach overlay is currently visible.
class TripDetailsCoachActiveScope extends InheritedWidget {
  const TripDetailsCoachActiveScope({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool of(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<TripDetailsCoachActiveScope>()
            ?.active ??
        false;
  }

  @override
  bool updateShouldNotify(TripDetailsCoachActiveScope oldWidget) {
    return oldWidget.active != active;
  }
}

/// Exposes manual replay for the trip-details coach tour.
class TripDetailsCoachScope extends InheritedWidget {
  const TripDetailsCoachScope({
    super.key,
    required this.replay,
    required this.isShowing,
    required super.child,
  });

  final VoidCallback replay;
  final bool isShowing;

  static VoidCallback? replayOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TripDetailsCoachScope>()
        ?.replay;
  }

  static bool isShowingOf(BuildContext context) {
    return context
            .dependOnInheritedWidgetOfExactType<TripDetailsCoachScope>()
            ?.isShowing ??
        false;
  }

  @override
  bool updateShouldNotify(TripDetailsCoachScope oldWidget) {
    return oldWidget.isShowing != isShowing;
  }
}

/// One-time coach tour on trip details — checks [SecureStorage] and overlays
/// [child] when the user has not seen the tour yet.
class TripDetailsCoachHost extends ConsumerStatefulWidget {
  const TripDetailsCoachHost({
    super.key,
    required this.child,
    required this.firstBoardingRowKey,
    required this.dropOffRowKey,
    required this.mapButtonKey,
    required this.tripLoaded,
  });

  final Widget child;
  final GlobalKey firstBoardingRowKey;
  final GlobalKey dropOffRowKey;
  final GlobalKey mapButtonKey;
  final bool tripLoaded;

  @override
  ConsumerState<TripDetailsCoachHost> createState() =>
      _TripDetailsCoachHostState();
}

class _TripDetailsCoachHostState extends ConsumerState<TripDetailsCoachHost> {
  bool _showCoach = false;
  bool _autoInitComplete = false;
  int _replayGeneration = 0;
  SecureStorage? _storage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => unawaited(_initCoach()));
  }

  SecureStorage get _secureStorage {
    _storage ??= ref.read(secureStorageProvider);
    return _storage!;
  }

  @override
  void didUpdateWidget(covariant TripDetailsCoachHost oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tripLoaded && !oldWidget.tripLoaded && !_autoInitComplete) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => unawaited(_initCoach()));
    }
  }

  Future<void> _initCoach() async {
    if (!mounted || _autoInitComplete || !widget.tripLoaded) return;

    final seen = await _secureStorage.tripDetailsCoachSeen();
    _autoInitComplete = true;
    if (!mounted || seen) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() => _showCoach = true);
  }

  void _replay() {
    if (_showCoach || !widget.tripLoaded) return;
    setState(() {
      _replayGeneration++;
      _showCoach = true;
    });
  }

  Future<void> _finishCoach() async {
    await _secureStorage.setTripDetailsCoachSeen();
    if (mounted) setState(() => _showCoach = false);
  }

  @override
  void dispose() {
    if (_showCoach) {
      unawaited(_storage?.setTripDetailsCoachSeen());
    }
    super.dispose();
  }

  List<CoachMarkStep> _steps(AppLocalizations l10n) => [
        CoachMarkStep(
          targetKey: widget.firstBoardingRowKey,
          title: l10n.tripDetailCoachStep1Title,
          body: l10n.tripDetailCoachStep1Body,
        ),
        CoachMarkStep(
          targetKey: widget.mapButtonKey,
          title: l10n.tripDetailCoachStep2Title,
          body: l10n.tripDetailCoachStep2Body,
        ),
        CoachMarkStep(
          targetKey: widget.dropOffRowKey,
          title: l10n.tripDetailCoachStep3Title,
          body: l10n.tripDetailCoachStep3Body,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return TripDetailsCoachScope(
      replay: _replay,
      isShowing: _showCoach,
      child: TripDetailsCoachActiveScope(
        active: _showCoach,
        child: Stack(
          children: [
            widget.child,
            if (_showCoach)
              Positioned.fill(
                child: CoachMarkOverlay(
                  key: ValueKey(_replayGeneration),
                  steps: _steps(l10n),
                  skipLabel: l10n.tripDetailCoachSkip,
                  nextLabel: l10n.tripDetailCoachNext,
                  doneLabel: l10n.tripDetailCoachDone,
                  onComplete: () => unawaited(_finishCoach()),
                  onSkip: () => unawaited(_finishCoach()),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

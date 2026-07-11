import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_icons.dart';
import 'package:rego/core/theme/app_spacing.dart';
import 'package:rego/core/theme/app_typography.dart';
import 'package:rego/features/bus/domain/entities/bus_stop.dart';
import 'package:rego/l10n/app_localizations.dart';

// ── Tunable geometry ─────────────────────────────────────────────────────────
const double _kHMargin = 62; // side inset; also caps the U-turn bulge on-canvas
const double _kTopPad = 64; // room for the first row's 2-line label above the line
const double _kBottomPad = 30;
const double _kRowStep = 116; // vertical gap between snaking rows
const double _kColMinSpacing = 108; // min horizontal spacing; fits 2-line labels
const int _kMaxColumns = 4;

/// One stop fed into the road layout, tagged with whether it is a boarding
/// (origin-city) candidate or a drop-off (destination-city) candidate.
class RouteStopInput {
  const RouteStopInput({required this.stop, required this.isBoardCandidate});
  final BusStop stop;
  final bool isBoardCandidate;
}

/// A stop placed on the road, with its computed centre point.
class RouteRoadNode {
  const RouteRoadNode({
    required this.stop,
    required this.isBoardCandidate,
    required this.index,
    required this.row,
    required this.center,
  });

  final BusStop stop;
  final bool isBoardCandidate;
  final int index;
  final int row;
  final Offset center;
}

/// The full computed road: nodes in route order plus the canvas size.
class RouteRoadLayout {
  const RouteRoadLayout({
    required this.nodes,
    required this.columns,
    required this.width,
    required this.height,
  });

  final List<RouteRoadNode> nodes;
  final int columns;
  final double width;
  final double height;
}

/// Lays [stops] out along a boustrophedon (snaking) grid so a road drawn
/// through them in order winds left-to-right, then right-to-left, row by row.
/// Works for any count — two stops collapse to a single row, many stops wrap.
/// When [startFromRight] (RTL), the first row runs right-to-left.
RouteRoadLayout computeRouteRoadLayout({
  required List<RouteStopInput> stops,
  required double width,
  bool startFromRight = false,
}) {
  final n = stops.length;
  if (n == 0) {
    return RouteRoadLayout(nodes: const [], columns: 0, width: width, height: 0);
  }

  final usable = math.max(1.0, width - 2 * _kHMargin);
  var cols = (usable / _kColMinSpacing).floor() + 1;
  cols = cols.clamp(1, _kMaxColumns);
  cols = math.min(cols, n);

  double xForColumn(int c) {
    if (cols == 1) return width / 2;
    final step = usable / (cols - 1);
    return _kHMargin + c * step;
  }

  final nodes = <RouteRoadNode>[];
  for (var i = 0; i < n; i++) {
    final row = i ~/ cols;
    final posInRow = i % cols;
    // Row 0 runs in the base direction; every row after reverses, so the road
    // snakes. RTL flips the base direction.
    final leftToRight = startFromRight ? row.isOdd : row.isEven;
    // Fill reversed rows from the far column so consecutive rows meet on the
    // same side — that shared edge is where the U-turn is drawn.
    final visualColumn = leftToRight ? posInRow : cols - 1 - posInRow;

    nodes.add(
      RouteRoadNode(
        stop: stops[i].stop,
        isBoardCandidate: stops[i].isBoardCandidate,
        index: i,
        row: row,
        center: Offset(xForColumn(visualColumn), _kTopPad + row * _kRowStep),
      ),
    );
  }

  final rows = ((n - 1) ~/ cols) + 1;
  final height = _kTopPad + (rows - 1) * _kRowStep + _kBottomPad;
  return RouteRoadLayout(
    nodes: nodes,
    columns: cols,
    width: width,
    height: height,
  );
}

enum _StopRole { pickup, dropoff }

/// Interactive winding-road view of a trip's full route. Boarding stops
/// (origin city) come first, then drop-off stops (destination city), each
/// sorted by arrival time. Tap a stop to focus it; long-press to open a menu
/// and assign it as the pickup (blue) or drop-off (amber) point — only the
/// role valid for that stop's side is offered, which keeps the chosen pair a
/// valid boarding/drop-off combination for the live fare and seat map.
class RouteRoad extends StatefulWidget {
  const RouteRoad({
    super.key,
    required this.boardingStops,
    required this.dropoffStops,
    required this.selectedFrom,
    required this.selectedTo,
    required this.onBoardSelected,
    required this.onDropoffSelected,
  });

  final List<BusStop> boardingStops;
  final List<BusStop> dropoffStops;
  final BusStop selectedFrom;
  final BusStop selectedTo;
  final ValueChanged<BusStop> onBoardSelected;
  final ValueChanged<BusStop> onDropoffSelected;

  @override
  State<RouteRoad> createState() => _RouteRoadState();
}

class _RouteRoadState extends State<RouteRoad> {
  int? _focusedIndex;

  /// Nulls sort first — a missing `arrivalAt` is treated as the earliest/base
  /// time (same convention as `BusTripSummary.departTime`), so the default
  /// boarding stop isn't buried at the end of its group.
  static int _byArrival(BusStop a, BusStop b) {
    if (a.arrivalAt == null && b.arrivalAt == null) return 0;
    if (a.arrivalAt == null) return -1;
    if (b.arrivalAt == null) return 1;
    return a.arrivalAt!.compareTo(b.arrivalAt!);
  }

  List<RouteStopInput> _buildInputs() {
    final board = [...widget.boardingStops]..sort(_byArrival);
    final drop = [...widget.dropoffStops]..sort(_byArrival);
    return [
      for (final s in board)
        RouteStopInput(stop: s, isBoardCandidate: true),
      for (final s in drop)
        RouteStopInput(stop: s, isBoardCandidate: false),
    ];
  }

  Future<void> _showRoleMenu(BuildContext nodeContext, RouteRoadNode node) async {
    final l10n = AppLocalizations.of(nodeContext);
    final box = nodeContext.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(nodeContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return;

    final topLeft = box.localToGlobal(Offset.zero, ancestor: overlay);
    final position = RelativeRect.fromRect(
      topLeft & box.size,
      Offset.zero & overlay.size,
    );

    final result = await showMenu<_StopRole>(
      context: nodeContext,
      position: position,
      items: [
        PopupMenuItem(
          value: _StopRole.pickup,
          enabled: node.isBoardCandidate,
          child: Row(
            children: [
              const Icon(AppIcons.locationFrom, size: 18,
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailBoardHere),
            ],
          ),
        ),
        PopupMenuItem(
          value: _StopRole.dropoff,
          enabled: !node.isBoardCandidate,
          child: Row(
            children: [
              const Icon(AppIcons.locationTo, size: 18,
                  color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text(l10n.tripDetailDropOffHere),
            ],
          ),
        ),
      ],
    );

    if (result == _StopRole.pickup) {
      widget.onBoardSelected(node.stop);
    } else if (result == _StopRole.dropoff) {
      widget.onDropoffSelected(node.stop);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final inputs = _buildInputs();

    return Material(
      color: AppColors.bgElevated,
      borderRadius: BorderRadius.circular(AppRadius.card),
      elevation: 3,
      shadowColor: AppColors.primary.withValues(alpha: 0.1),
      child: Padding(
        padding: AppSpacing.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.tripDetailRouteSection,
              style: AppTypography.title.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final layout = computeRouteRoadLayout(
                  stops: inputs,
                  width: width,
                  startFromRight: rtl,
                );
                final pickupIndex = layout.nodes.indexWhere(
                  (n) =>
                      n.isBoardCandidate &&
                      n.stop.locationId == widget.selectedFrom.locationId,
                );
                final dropoffIndex = layout.nodes.indexWhere(
                  (n) =>
                      !n.isBoardCandidate &&
                      n.stop.locationId == widget.selectedTo.locationId,
                );

                return SizedBox(
                  width: width,
                  height: layout.height,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _RoadPainter(
                            layout: layout,
                            pickupIndex: pickupIndex,
                            dropoffIndex: dropoffIndex,
                            focusedIndex: _focusedIndex,
                          ),
                        ),
                      ),
                      for (final node in layout.nodes)
                        _RouteNodeHotspot(
                          node: node,
                          canvasWidth: width,
                          isSelected: node.index == pickupIndex ||
                              node.index == dropoffIndex,
                          onTap: () =>
                              setState(() => _focusedIndex = node.index),
                          onLongPress: (ctx) => _showRoleMenu(ctx, node),
                        ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// A stop's label (name + time) plus its transparent tap/long-press target,
/// positioned so the hit area covers both the label and the road dot below it.
class _RouteNodeHotspot extends StatelessWidget {
  const _RouteNodeHotspot({
    required this.node,
    required this.canvasWidth,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
  });

  final RouteRoadNode node;
  final double canvasWidth;
  final bool isSelected;
  final VoidCallback onTap;
  final void Function(BuildContext nodeContext) onLongPress;

  static const double _halfWidth = 50;
  static const double _labelArea = 50; // fixed label region above the dot
  static const double _labelGap = 12; // clearance between label and dot
  static const double _dotHit = 16; // tappable region over the dot

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        node.isBoardCandidate ? AppColors.primary : AppColors.secondary;
    final left =
        (node.center.dx - _halfWidth).clamp(0.0, canvasWidth - 2 * _halfWidth);

    return Positioned(
      left: left,
      top: node.center.dy - _labelArea - _labelGap,
      width: 2 * _halfWidth,
      height: _labelArea + _labelGap + _dotHit,
      child: Builder(
        builder: (nodeContext) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: () => onLongPress(nodeContext),
          child: Column(
            children: [
              SizedBox(
                height: _labelArea,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        node.stop.name,
                        maxLines: 2,
                        textAlign: TextAlign.center,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                          color: isSelected ? accent : AppColors.textPrimary,
                        ),
                      ),
                      if (node.stop.arrivalAt != null)
                        Text(
                          _formatTime(node.stop.arrivalAt!),
                          maxLines: 1,
                          style: AppTypography.caption.copyWith(
                            fontWeight: FontWeight.w600,
                            color:
                                isSelected ? accent : AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadPainter extends CustomPainter {
  _RoadPainter({
    required this.layout,
    required this.pickupIndex,
    required this.dropoffIndex,
    required this.focusedIndex,
  });

  final RouteRoadLayout layout;
  final int pickupIndex;
  final int dropoffIndex;
  final int? focusedIndex;

  Path _roadPath(List<RouteRoadNode> nodes) {
    final path = Path();
    if (nodes.isEmpty) return path;
    path.moveTo(nodes.first.center.dx, nodes.first.center.dy);
    for (var i = 1; i < nodes.length; i++) {
      final prev = nodes[i - 1];
      final cur = nodes[i];
      if (prev.row == cur.row) {
        path.lineTo(cur.center.dx, cur.center.dy);
      } else {
        // Row change: both nodes share the same edge x, so draw a U-turn
        // semicircle bulging outward (right edge → clockwise, left → not).
        final chord = (cur.center - prev.center).distance;
        final radius = math.max(_kRowStep / 2, chord / 2);
        path.arcToPoint(
          cur.center,
          radius: Radius.circular(radius),
          clockwise: prev.center.dx > layout.width / 2,
        );
      }
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final nodes = layout.nodes;
    if (nodes.isEmpty) return;

    final fullPath = _roadPath(nodes);

    // Thin route line — no filled grey road band.
    canvas.drawPath(
      fullPath,
      Paint()
        ..color = AppColors.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Highlight the travelled segment between pickup and drop-off.
    if (pickupIndex >= 0 && dropoffIndex >= 0) {
      final lo = math.min(pickupIndex, dropoffIndex);
      final hi = math.max(pickupIndex, dropoffIndex);
      final segment = _roadPath(nodes.sublist(lo, hi + 1));
      canvas.drawPath(
        segment,
        Paint()
          ..color = AppColors.primary
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Stop markers.
    for (final node in nodes) {
      final accent =
          node.isBoardCandidate ? AppColors.primary : AppColors.secondary;
      final selected =
          node.index == pickupIndex || node.index == dropoffIndex;

      if (selected) {
        canvas.drawCircle(node.center, 12, Paint()..color = accent);
        canvas.drawCircle(
          node.center,
          4.5,
          Paint()..color = AppColors.onPrimary,
        );
      } else {
        if (node.index == focusedIndex) {
          canvas.drawCircle(
            node.center,
            11,
            Paint()
              ..color = accent
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2,
          );
        }
        canvas.drawCircle(node.center, 6, Paint()..color = AppColors.bgElevated);
        canvas.drawCircle(
          node.center,
          6,
          Paint()
            ..color = accent
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RoadPainter old) {
    return old.layout != layout ||
        old.pickupIndex != pickupIndex ||
        old.dropoffIndex != dropoffIndex ||
        old.focusedIndex != focusedIndex;
  }
}

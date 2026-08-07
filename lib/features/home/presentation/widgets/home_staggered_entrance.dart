import 'package:flutter/material.dart';

/// Fade + slide entrance for home body sections after the hero loads.
class HomeStaggeredEntrance extends StatefulWidget {
  const HomeStaggeredEntrance({
    super.key,
    required this.index,
    required this.child,
  });

  final int index;
  final Widget child;

  static const _baseDelay = Duration(milliseconds: 60);
  static const _duration = Duration(milliseconds: 420);
  static const _curve = Curves.easeOutCubic;

  @override
  State<HomeStaggeredEntrance> createState() => _HomeStaggeredEntranceState();
}

class _HomeStaggeredEntranceState extends State<HomeStaggeredEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: HomeStaggeredEntrance._duration);
    _opacity = CurvedAnimation(
        parent: _controller, curve: HomeStaggeredEntrance._curve);
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
        parent: _controller, curve: HomeStaggeredEntrance._curve));
    Future<void>.delayed(
      HomeStaggeredEntrance._baseDelay * widget.index,
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

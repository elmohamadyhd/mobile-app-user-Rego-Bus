import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:rego/core/theme/app_colors.dart';
import 'package:rego/core/theme/app_typography.dart';

/// A row of single-digit OTP boxes with auto-advance and backspace handling.
/// Filled boxes tint blue, matching the Skyline design.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    this.length = 4,
    required this.onChanged,
    this.onCompleted,
    this.hasError = false,
  });

  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final bool hasError;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) {
      final node = FocusNode();
      node.addListener(() => setState(() {}));
      return node;
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  String get _value => _controllers.map((c) => c.text).join();

  void _handlePaste(String digits) {
    if (digits.isEmpty) return;
    final clipped = digits.length > widget.length
        ? digits.substring(0, widget.length)
        : digits;
    for (var j = 0; j < widget.length; j++) {
      _controllers[j].text = j < clipped.length ? clipped[j] : '';
    }
    _nodes[(clipped.length - 1).clamp(0, widget.length - 1)].requestFocus();
    _notify();
  }

  void _notify() {
    final value = _value;
    widget.onChanged(value);
    if (value.length == widget.length &&
        _controllers.every((c) => c.text.isNotEmpty)) {
      widget.onCompleted?.call(value);
    }
    setState(() {});
  }

  void _onChanged(int i, String v) {
    if (v.isNotEmpty && i < widget.length - 1) {
      _nodes[i + 1].requestFocus();
    } else if (v.isEmpty && i > 0) {
      _nodes[i - 1].requestFocus();
    }

    _notify();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < widget.length; i++) ...[
          Expanded(child: _box(i)),
          if (i != widget.length - 1) const SizedBox(width: 14),
        ],
      ],
    );
  }

  Widget _box(int i) {
    final filled = _controllers[i].text.isNotEmpty;
    final active = _nodes[i].hasFocus;
    final borderColor = widget.hasError
        ? AppColors.error
        : (filled || active ? AppColors.primary : AppColors.hairline);

    return Container(
      height: 64,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: filled ? AppColors.primaryTint : AppColors.bgCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: TextField(
        controller: _controllers[i],
        focusNode: _nodes[i],
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        showCursor: true,
        cursorColor: AppColors.primary,
        style: AppTypography.display.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          TextInputFormatter.withFunction((oldValue, newValue) {
            if (newValue.text.length - oldValue.text.length >= 2) {
              Future.microtask(() => _handlePaste(newValue.text));
              return oldValue;
            }
            return newValue;
          }),
        ],
        decoration: const InputDecoration(
          counterText: '',
          filled: false,
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
        onChanged: (v) => _onChanged(i, v),
      ),
    );
  }
}

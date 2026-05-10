import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.backgroundColor,
    this.foregroundColor,
  });

  final double value;
  final double height;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0, 1),
        backgroundColor:
            backgroundColor ?? Theme.of(context).colorScheme.outlineVariant,
        valueColor: AlwaysStoppedAnimation(
          foregroundColor ?? const Color(0xFF7D8A5E),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    this.height = 10,
    this.backgroundColor = const Color(0xFFE1D3BE),
    this.foregroundColor = const Color(0xFF7D8A5E),
  });

  final double value;
  final double height;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        minHeight: height,
        value: value.clamp(0, 1),
        backgroundColor: backgroundColor,
        valueColor: AlwaysStoppedAnimation(foregroundColor),
      ),
    );
  }
}

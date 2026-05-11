import 'package:flutter/material.dart';

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Center(
        child: Icon(
          Icons.calendar_month_rounded,
          size: 54,
          color: scheme.primary,
        ),
      ),
    );
  }
}

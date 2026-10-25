import 'package:flutter/material.dart';

class BottomUnderstandingControls extends StatelessWidget {
  const BottomUnderstandingControls({
    super.key,
    required this.onNotUnderstood,
    required this.onUnderstood,
    this.notUnderstoodLabel = '❌ 不懂',
    this.understoodLabel = '✅ 懂了',
  });

  final VoidCallback onNotUnderstood;
  final VoidCallback onUnderstood;
  final String notUnderstoodLabel;
  final String understoodLabel;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      minimum: const EdgeInsets.fromLTRB(16, 10, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB25B4F),
                  foregroundColor: const Color(0xFFFFFAF1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: onNotUnderstood,
                child: Text(
                  notUnderstoodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 58,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7D8A5E),
                  foregroundColor: const Color(0xFFFFFAF1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                onPressed: onUnderstood,
                child: Text(
                  understoodLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

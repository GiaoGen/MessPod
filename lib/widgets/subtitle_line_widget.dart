import 'package:flutter/material.dart';

import '../models/subtitle_line.dart';

class SubtitleLineWidget extends StatelessWidget {
  const SubtitleLineWidget({
    super.key,
    required this.line,
    required this.isCurrent,
    required this.onTap,
    required this.onWordTap,
  });

  final SubtitleLine line;
  final bool isCurrent;
  final VoidCallback onTap;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (line.status) {
      SubtitleStatus.understood => const Color(0xFF6F7D4E),
      SubtitleStatus.notUnderstood => const Color(0xFFB25B4F),
      SubtitleStatus.unknown => const Color(0xFFB7A58E),
    };
    final icon = switch (line.status) {
      SubtitleStatus.understood => Icons.check_circle_rounded,
      SubtitleStatus.notUnderstood => Icons.cancel_rounded,
      SubtitleStatus.unknown => Icons.circle_outlined,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent ? const Color(0xFF4E3A2C) : const Color(0xFFFFFAF1),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isCurrent
                ? const Color(0xFF4E3A2C)
                : const Color(0xFFE1D3BE),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Icon(
                icon,
                color: isCurrent ? const Color(0xFFF3EBDD) : statusColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Wrap(
                runSpacing: 8,
                children: _tokens(line.text).map((token) {
                  final word = _cleanWord(token);
                  final clickable = word.isNotEmpty;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: clickable ? () => onWordTap(word) : null,
                      child: Text(
                        token,
                        style: TextStyle(
                          color: isCurrent
                              ? const Color(0xFFFFFAF1)
                              : const Color(0xFF3C2C20),
                          fontSize: isCurrent ? 21 : 19,
                          height: 1.35,
                          fontWeight: isCurrent
                              ? FontWeight.w900
                              : FontWeight.w700,
                          decoration: clickable
                              ? TextDecoration.underline
                              : TextDecoration.none,
                          decorationColor: isCurrent
                              ? const Color(0xFFD8C8B1)
                              : const Color(0xFF9A8764),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static List<String> _tokens(String text) {
    return text
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();
  }

  static String _cleanWord(String token) {
    return token.replaceAll(RegExp(r'[^a-zA-Z]'), '').toLowerCase();
  }
}

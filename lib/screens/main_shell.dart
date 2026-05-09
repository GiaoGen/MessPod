import 'package:flutter/material.dart';

import '../widgets/add_video_sheet.dart';
import 'home_screen.dart';
import 'vocabulary_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), VocabularyScreen()],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        child: Row(
          children: [
            Expanded(
              child: Container(
                height: 62,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4E3A2C),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _BottomTab(
                      selected: _index == 0,
                      icon: Icons.home_rounded,
                      label: '首页',
                      onTap: () => setState(() => _index = 0),
                    ),
                    _BottomTab(
                      selected: _index == 1,
                      icon: Icons.bookmark_rounded,
                      label: '生词本',
                      onTap: () => setState(() => _index = 1),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 62,
              height: 62,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6048),
                  foregroundColor: const Color(0xFFFFFAF1),
                  padding: EdgeInsets.zero,
                  shape: const CircleBorder(),
                ),
                onPressed: () => showAddVideoSheet(context),
                child: const Icon(Icons.add_rounded, size: 32),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BottomTab extends StatelessWidget {
  const _BottomTab({
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFF3EBDD) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? const Color(0xFF4E3A2C)
                    : const Color(0xFFD8C8B1),
              ),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF4E3A2C)
                        : const Color(0xFFD8C8B1),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
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

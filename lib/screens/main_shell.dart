import 'package:flutter/material.dart';

import '../widgets/add_video_sheet.dart';
import 'calendar_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
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
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: const [
                HomeScreen(),
                VocabularyScreen(),
                CalendarScreen(),
                SettingsScreen(),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
              minimum: const EdgeInsets.fromLTRB(18, 0, 18, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 62,
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        border: Border.all(color: scheme.outlineVariant),
                        borderRadius: BorderRadius.circular(999),
                        boxShadow: [
                          BoxShadow(
                            color: scheme.shadow.withValues(alpha: 0.14),
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
                          _BottomTab(
                            selected: _index == 2,
                            icon: Icons.calendar_month_rounded,
                            label: '日历',
                            onTap: () => setState(() => _index = 2),
                          ),
                          _BottomTab(
                            selected: _index == 3,
                            icon: Icons.settings_rounded,
                            label: '设置',
                            onTap: () => setState(() => _index = 3),
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
                        backgroundColor: scheme.primary,
                        foregroundColor: scheme.onPrimary,
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
          ),
        ],
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
    final scheme = Theme.of(context).colorScheme;

    return Expanded(
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Icon(
              icon,
              color: selected
                  ? scheme.onPrimary
                  : scheme.onSurfaceVariant.withValues(alpha: 0.82),
            ),
          ),
        ),
      ),
    );
  }
}

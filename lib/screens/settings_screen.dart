import 'package:flutter/material.dart';

import 'youtube_login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 116),
        children: [
          Text(
            '设置',
            style: TextStyle(
              color: scheme.onSurface,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Material(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(28),
            child: ListTile(
              minTileHeight: 72,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              leading: Icon(
                Icons.account_circle_rounded,
                color: scheme.primary,
              ),
              title: Text(
                '登录 YouTube',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              trailing: Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurfaceVariant,
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const YoutubeLoginScreen(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

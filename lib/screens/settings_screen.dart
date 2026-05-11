import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../services/dictionary_file_picker.dart';
import '../services/dictionary_service.dart';
import 'youtube_login_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final DictionaryFilePicker _filePicker = DictionaryFilePicker();
  bool _isImportingDictionary = false;
  String? _dictionaryMessage;

  Future<void> _importDictionary() async {
    if (_isImportingDictionary) {
      return;
    }

    setState(() {
      _isImportingDictionary = true;
      _dictionaryMessage = '正在选择词典文件';
    });

    try {
      final picked = await _filePicker.pickDictionaryFile();
      if (!mounted) {
        return;
      }
      if (picked == null) {
        setState(() {
          _isImportingDictionary = false;
          _dictionaryMessage = null;
        });
        return;
      }

      setState(() => _dictionaryMessage = '正在导入 ${picked.name}');
      final result = await context.read<AppState>().importDictionaryFromFile(
        File(picked.path),
      );
      if (!mounted) {
        return;
      }

      setState(() {
        _isImportingDictionary = false;
        _dictionaryMessage =
            '已导入 ${result.entryCount} 个词条，跳过 ${result.skippedCount} 条';
      });
    } on DictionaryFormatException catch (error) {
      _finishImportWithError(error.message);
    } catch (error) {
      _finishImportWithError('导入失败：$error');
    }
  }

  void _finishImportWithError(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isImportingDictionary = false;
      _dictionaryMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dictionary = appState.dictionary;
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
          _SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.menu_book_rounded, color: scheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '词典管理',
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  dictionary.hasLocalDictionary
                      ? '当前词典：${dictionary.localDictionaryName ?? '本地词典'}'
                      : '当前词典：未导入',
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  dictionary.hasLocalDictionary
                      ? '${dictionary.localEntryCount} 个词条。支持 PyGlossary Tabfile / CSV / JSON'
                      : '建议用 PyGlossary 导出 Tabfile、CSV 或 JSON。',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (_isImportingDictionary) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    borderRadius: BorderRadius.circular(999),
                    color: scheme.primary,
                    backgroundColor: scheme.surfaceContainerHighest,
                  ),
                ],
                if (_dictionaryMessage != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _dictionaryMessage!,
                    style: TextStyle(
                      color: _isImportingDictionary
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed:
                      _isImportingDictionary ? null : _importDictionary,
                  icon: const Icon(Icons.upload_file_rounded),
                  label: const Text('导入词典'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _SettingsCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 62,
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

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(28),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

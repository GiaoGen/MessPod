import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/vocabulary_item.dart';
import '../providers/app_state.dart';
import 'dictionary_entry_screen.dart';

class VocabularyScreen extends StatefulWidget {
  const VocabularyScreen({super.key});

  @override
  State<VocabularyScreen> createState() => _VocabularyScreenState();
}

class _VocabularyScreenState extends State<VocabularyScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _expandedWords = {};

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final groups = _groupItems(appState);
    final scheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                '生词本',
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (groups.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(
                    '还没有收藏的单词\n在字幕里点单词即可加入',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 18,
                      height: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
              sliver: SliverList.separated(
                itemCount: groups.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final group = groups[index];
                  final expanded = _expandedWords.contains(group.key);

                  return Material(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(30),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 10, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(22),
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => DictionaryEntryScreen(
                                          entry: appState.dictionary.lookup(
                                            group.word,
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    child: Text(
                                      group.displayWord,
                                      style: TextStyle(
                                        color: scheme.onSurface,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton.filledTonal(
                                tooltip: expanded ? '收起来源' : '查看来源',
                                style: IconButton.styleFrom(
                                  backgroundColor:
                                      scheme.surfaceContainerHighest,
                                  foregroundColor: scheme.primary,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (expanded) {
                                      _expandedWords.remove(group.key);
                                    } else {
                                      _expandedWords.add(group.key);
                                    }
                                  });
                                },
                                icon: AnimatedRotation(
                                  turns: expanded ? 0.5 : 0,
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  child: const Icon(
                                    Icons.keyboard_arrow_down_rounded,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          AnimatedSize(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: expanded
                                ? Column(
                                    children: [
                                      Divider(
                                        height: 8,
                                        color: scheme.outlineVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 8),
                                      for (final item in group.items)
                                        _VocabularySourceRow(
                                          item: item,
                                          onRemove: () => appState
                                              .removeVocabulary(item.id),
                                        ),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  List<_VocabularyGroup> _groupItems(AppState appState) {
    final groups = <String, _VocabularyGroup>{};
    for (final item in appState.vocabularyItems) {
      final word = item.word.trim();
      if (word.isEmpty) {
        continue;
      }
      final key = word.toLowerCase();
      final group = groups.putIfAbsent(
        key,
        () => _VocabularyGroup(
          key: key,
          word: word,
          displayWord: word,
          items: [],
        ),
      );
      group.items.add(item);
    }
    return groups.values.toList();
  }
}

class _VocabularySourceRow extends StatelessWidget {
  const _VocabularySourceRow({
    required this.item,
    required this.onRemove,
  });

  final VocabularyItem item;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.sourceVideoTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.sourceSubtitleText,
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 16,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatTime(item.createdAt),
                  style: TextStyle(
                    color: scheme.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: '取消收藏',
            visualDensity: VisualDensity.compact,
            onPressed: onRemove,
            icon: Icon(
              Icons.close_rounded,
              color: scheme.onSurfaceVariant,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatTime(DateTime time) {
    return '${time.year}-${_two(time.month)}-${_two(time.day)} ${_two(time.hour)}:${_two(time.minute)}';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}

class _VocabularyGroup {
  _VocabularyGroup({
    required this.key,
    required this.word,
    required this.displayWord,
    required this.items,
  });

  final String key;
  final String word;
  final String displayWord;
  final List<VocabularyItem> items;
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';

class VocabularyScreen extends StatelessWidget {
  const VocabularyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final items = appState.vocabularyItems;

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                '生词本',
                style: TextStyle(
                  color: Color(0xFF3C2C20),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (items.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '还没有收藏的单词\n在字幕里点单词即可加入',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7B6048),
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
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = items[index];
                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFAF1),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                item.word,
                                style: const TextStyle(
                                  color: Color(0xFF3C2C20),
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            IconButton.filledTonal(
                              tooltip: '取消收藏',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFF3EBDD),
                                foregroundColor: const Color(0xFF8D4C42),
                              ),
                              onPressed: () =>
                                  appState.removeVocabulary(item.id),
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.meaning,
                          style: const TextStyle(
                            color: Color(0xFF6E5139),
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.sourceVideoTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF7B6048),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.sourceSubtitleText,
                          style: const TextStyle(
                            color: Color(0xFF3C2C20),
                            fontSize: 16,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          _formatTime(item.createdAt),
                          style: const TextStyle(
                            color: Color(0xFF9A8764),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  );
                },
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

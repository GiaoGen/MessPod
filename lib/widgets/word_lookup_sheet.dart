import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../providers/app_state.dart';

Future<void> showWordLookupSheet({
  required BuildContext context,
  required String word,
  required VideoItem video,
  required String subtitleText,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        WordLookupSheet(word: word, video: video, subtitleText: subtitleText),
  );
}

class WordLookupSheet extends StatelessWidget {
  const WordLookupSheet({
    super.key,
    required this.word,
    required this.video,
    required this.subtitleText,
  });

  final String word;
  final VideoItem video;
  final String subtitleText;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final entry = appState.dictionary.lookup(word);
    final saved = appState.isVocabularySaved(entry.word, subtitleText);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF1),
          borderRadius: BorderRadius.circular(34),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD8C8B1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                entry.word,
                style: const TextStyle(
                  color: Color(0xFF3C2C20),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                entry.meaning,
                style: const TextStyle(
                  color: Color(0xFF6E5139),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: saved
                              ? const Color(0xFFE1D3BE)
                              : const Color(0xFF7B6048),
                          foregroundColor: saved
                              ? const Color(0xFF4E3A2C)
                              : const Color(0xFFFFFAF1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        onPressed: () => appState.addOrRemoveVocabulary(
                          word: entry.word,
                          sourceVideoId: video.id,
                          sourceVideoTitle: video.title,
                          sourceSubtitleText: subtitleText,
                        ),
                        icon: Icon(
                          saved
                              ? Icons.star_rounded
                              : Icons.star_border_rounded,
                        ),
                        label: Text(saved ? '取消收藏' : '加入生词本'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF6E5139),
                        side: const BorderSide(color: Color(0xFFD0BEA7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () {
                        showDialog<void>(
                          context: context,
                          builder: (_) => AlertDialog(
                            backgroundColor: const Color(0xFFFFFAF1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            title: Text(entry.word),
                            content: Text(entry.fullMeaning),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('知道了'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('完整释义'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

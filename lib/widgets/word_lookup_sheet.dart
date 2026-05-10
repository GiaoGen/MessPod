import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/video_item.dart';
import '../providers/app_state.dart';

Future<void> showWordLookupDialog({
  required BuildContext context,
  required String word,
  required VideoItem video,
  required String subtitleText,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) =>
        WordLookupDialog(word: word, video: video, subtitleText: subtitleText),
  );
}

class WordLookupDialog extends StatelessWidget {
  const WordLookupDialog({
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
    final scheme = Theme.of(context).colorScheme;

    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 14, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 10, 22, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      title: Row(
        children: [
          Expanded(
            child: Text(
              entry.word,
              style: TextStyle(
                color: scheme.onSurface,
                fontSize: 28,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          IconButton.filledTonal(
            tooltip: saved ? '取消收藏' : '加入生词本',
            style: IconButton.styleFrom(
              backgroundColor: saved ? scheme.primary : scheme.surfaceContainerHighest,
              foregroundColor: saved ? scheme.onPrimary : scheme.primary,
            ),
            onPressed: () => appState.addOrRemoveVocabulary(
              word: entry.word,
              sourceVideoId: video.id,
              sourceVideoTitle: video.title,
              sourceSubtitleText: subtitleText,
            ),
            icon: Icon(saved ? Icons.star_rounded : Icons.star_border_rounded),
          ),
        ],
      ),
      content: Text(
        entry.meaning,
        style: TextStyle(
          color: scheme.primary,
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: scheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
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
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('关闭'),
        ),
      ],
    );
  }
}

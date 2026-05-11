import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/video_item.dart';
import '../providers/app_state.dart';
import '../services/dictionary_service.dart';

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

Future<void> showDictionaryMeaningDialog({
  required BuildContext context,
  required DictionaryEntry entry,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _FullMeaningDialog(entry: entry),
  );
}

class DictionaryHtmlView extends StatelessWidget {
  const DictionaryHtmlView({super.key, required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    return _DictionaryHtmlView(entry: entry);
  }
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
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.52)
        .clamp(300.0, 430.0)
        .toDouble();

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
              backgroundColor:
                  saved ? scheme.primary : scheme.surfaceContainerHighest,
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
      content: SizedBox(
        width: double.maxFinite,
        height: contentHeight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _DictionaryHtmlView(entry: entry)),
            const SizedBox(height: 10),
            Text(
              entry.isLocal
                  ? '来自本地词典：${entry.source ?? '本地词典'}'
                  : '来自内置兜底词库',
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            showDialog<void>(
              context: context,
              builder: (_) => _FullMeaningDialog(entry: entry),
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

class _FullMeaningDialog extends StatelessWidget {
  const _FullMeaningDialog({required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final contentHeight = (MediaQuery.sizeOf(context).height * 0.68)
        .clamp(360.0, 560.0)
        .toDouble();

    return AlertDialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Text(entry.word),
      content: SizedBox(
        width: double.maxFinite,
        height: contentHeight,
        child: _DictionaryHtmlView(entry: entry),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    );
  }
}

class _DictionaryHtmlView extends StatefulWidget {
  const _DictionaryHtmlView({required this.entry});

  final DictionaryEntry entry;

  @override
  State<_DictionaryHtmlView> createState() => _DictionaryHtmlViewState();
}

class _DictionaryHtmlViewState extends State<_DictionaryHtmlView> {
  WebViewController? _controller;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) {
      return;
    }

    _loaded = true;
    final html = DictionaryService.htmlForDisplay(
      widget.entry.html?.trim().isNotEmpty == true
          ? widget.entry.html!
          : widget.entry.fullMeaning,
      headword: widget.entry.word,
    );
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.disabled)
      ..setBackgroundColor(Colors.transparent)
      ..loadHtmlString(_wrapHtml(html, Theme.of(context).colorScheme));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: WebViewWidget(controller: controller),
    );
  }

  String _wrapHtml(String body, ColorScheme scheme) {
    final textColor = _hex(scheme.onSurface);
    final background = _hex(scheme.surface);
    final muted = _hex(scheme.onSurfaceVariant);
    final accent = _hex(scheme.primary);

    return '''
<!doctype html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    html, body {
      margin: 0;
      padding: 0;
      color: $textColor;
      background: $background;
      font-family: sans-serif;
      font-size: 18px;
      line-height: 1.65;
      overflow-wrap: anywhere;
      word-break: normal;
    }
    body { padding: 8px 2px 20px; }
    .entry-title {
      color: $textColor;
      font-size: 28px;
      line-height: 1.25;
      font-weight: 800;
      margin: 0 0 16px;
    }
    .headword, .headword-text { display: none; }
    .phonetic {
      color: $muted;
      font-size: 18px;
      margin-left: 6px;
    }
    .pos, .label {
      color: $textColor;
      font-weight: 800;
      margin-right: 4px;
    }
    .sense, .definition, .unit {
      margin: 10px 0 14px;
    }
    .sense-number, .sense-letter {
      color: $accent;
      font-weight: 900;
      margin-right: 6px;
    }
    .en {
      color: $textColor;
      font-weight: 700;
    }
    .zh {
      color: $textColor;
      margin-left: 4px;
    }
    .example {
      margin: 12px 0 18px;
      color: $muted;
    }
    a { color: $accent; text-decoration: none; }
    img { max-width: 100%; height: auto; }
  </style>
</head>
<body>$body</body>
</html>
''';
  }

  String _hex(Color color) {
    final value = color.toARGB32() & 0xFFFFFF;
    return '#${value.toRadixString(16).padLeft(6, '0')}';
  }
}

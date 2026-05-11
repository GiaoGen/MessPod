import 'package:flutter/material.dart';

import '../services/dictionary_service.dart';
import '../widgets/word_lookup_sheet.dart';

class DictionaryEntryScreen extends StatelessWidget {
  const DictionaryEntryScreen({super.key, required this.entry});

  final DictionaryEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          entry.word,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (entry.isLocal) ...[
                Text(
                  '来自本地词典：${entry.source ?? '本地词典'}',
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: DictionaryHtmlView(entry: entry),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

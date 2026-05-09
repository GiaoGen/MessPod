class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.meaning,
    required this.fullMeaning,
  });

  final String word;
  final String meaning;
  final String fullMeaning;
}

class DictionaryService {
  static const Map<String, String> _meanings = {
    'hello': '你好',
    'world': '世界',
    'learn': '学习',
    'language': '语言',
    'understand': '理解',
  };

  DictionaryEntry lookup(String word) {
    final normalized = word.toLowerCase().trim();
    final meaning = _meanings[normalized] ?? '暂未收录，后续接入词典 API';

    return DictionaryEntry(
      word: normalized,
      meaning: meaning,
      fullMeaning: _meanings.containsKey(normalized)
          ? '$normalized：$meaning。MVP 释义：可结合字幕原句记忆，并在复习时反复听原音。'
          : '$normalized：暂未收录完整释义。MVP 后续可以接入真实词典 API、例句和发音。',
    );
  }
}

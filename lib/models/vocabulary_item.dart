class VocabularyItem {
  const VocabularyItem({
    required this.id,
    required this.word,
    required this.meaning,
    required this.sourceVideoId,
    required this.sourceVideoTitle,
    required this.sourceSubtitleText,
    required this.createdAt,
    this.dictionarySource,
  });

  final String id;
  final String word;
  final String meaning;
  final String sourceVideoId;
  final String sourceVideoTitle;
  final String sourceSubtitleText;
  final DateTime createdAt;
  final String? dictionarySource;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'word': word,
      'meaning': meaning,
      'sourceVideoId': sourceVideoId,
      'sourceVideoTitle': sourceVideoTitle,
      'sourceSubtitleText': sourceSubtitleText,
      'createdAt': createdAt.toIso8601String(),
      'dictionarySource': dictionarySource,
    };
  }

  factory VocabularyItem.fromJson(Map<String, dynamic> json) {
    return VocabularyItem(
      id: json['id'] as String,
      word: json['word'] as String,
      meaning: json['meaning'] as String,
      sourceVideoId: json['sourceVideoId'] as String,
      sourceVideoTitle: json['sourceVideoTitle'] as String,
      sourceSubtitleText: json['sourceSubtitleText'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      dictionarySource: json['dictionarySource'] as String?,
    );
  }
}

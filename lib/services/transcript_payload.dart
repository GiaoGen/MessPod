class TranscriptVideoPayload {
  const TranscriptVideoPayload({
    required this.title,
    required this.durationSeconds,
    required this.subtitles,
  });

  final String title;
  final int durationSeconds;
  final List<TranscriptLinePayload> subtitles;

  factory TranscriptVideoPayload.fromJson(Map<String, dynamic> json) {
    final title = (json['title'] as String?)?.trim();

    return TranscriptVideoPayload(
      title: title == null || title.isEmpty ? 'Untitled YouTube video' : title,
      durationSeconds: (json['durationSeconds'] as num?)?.round() ?? 0,
      subtitles: ((json['subtitles'] as List<dynamic>?) ?? [])
          .whereType<Map<String, dynamic>>()
          .map(TranscriptLinePayload.fromJson)
          .where((line) => line.text.isNotEmpty)
          .toList(),
    );
  }
}

class TranscriptLinePayload {
  const TranscriptLinePayload({
    required this.start,
    required this.duration,
    required this.text,
  });

  final double start;
  final double duration;
  final String text;

  factory TranscriptLinePayload.fromJson(Map<String, dynamic> json) {
    return TranscriptLinePayload(
      start: (json['start'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      text: (json['text'] as String).trim(),
    );
  }
}

class TranscriptApiException implements Exception {
  const TranscriptApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

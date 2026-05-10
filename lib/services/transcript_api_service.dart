import 'dart:async';
import 'dart:convert';
import 'dart:io';

class TranscriptApiService {
  TranscriptApiService({
    HttpClient? client,
    String? baseUrl,
  }) : _client = client ?? HttpClient(),
       _baseUrl =
           baseUrl ??
           const String.fromEnvironment(
             'TRANSCRIPT_API_BASE_URL',
             defaultValue: 'http://10.0.2.2:8000',
           );

  final HttpClient _client;
  final String _baseUrl;

  Future<TranscriptVideoPayload> fetchVideo(String youtubeVideoId) async {
    final uri = Uri.parse('$_baseUrl/videos/$youtubeVideoId');
    final request = await _client.getUrl(uri).timeout(
      const Duration(seconds: 15),
    );
    final response = await request.close().timeout(const Duration(seconds: 15));
    final body = await utf8.decodeStream(response).timeout(
      const Duration(seconds: 15),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranscriptApiException(
        'Transcript API failed (${response.statusCode})',
      );
    }

    final json = jsonDecode(body);
    if (json is! Map<String, dynamic>) {
      throw const TranscriptApiException('Invalid transcript payload');
    }

    return TranscriptVideoPayload.fromJson(json);
  }
}

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

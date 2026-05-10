import 'subtitle_line.dart';

class VideoItem {
  const VideoItem({
    required this.id,
    required this.youtubeVideoId,
    required this.url,
    required this.title,
    required this.thumbnailUrl,
    required this.durationSeconds,
    required this.subtitles,
    required this.createdAt,
    this.lastPositionSeconds = 0,
    this.lastSubtitleId,
    this.subtitleOffsetSeconds = 0,
    this.subtitleAutoScrollEnabled = true,
  });

  final String id;
  final String youtubeVideoId;
  final String url;
  final String title;
  final String thumbnailUrl;
  final int durationSeconds;
  final List<SubtitleLine> subtitles;
  final DateTime createdAt;
  final double lastPositionSeconds;
  final String? lastSubtitleId;
  final double subtitleOffsetSeconds;
  final bool subtitleAutoScrollEnabled;

  VideoItem copyWith({
    String? title,
    int? durationSeconds,
    List<SubtitleLine>? subtitles,
    double? lastPositionSeconds,
    String? lastSubtitleId,
    double? subtitleOffsetSeconds,
    bool? subtitleAutoScrollEnabled,
  }) {
    return VideoItem(
      id: id,
      youtubeVideoId: youtubeVideoId,
      url: url,
      title: title ?? this.title,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      subtitles: subtitles ?? this.subtitles,
      createdAt: createdAt,
      lastPositionSeconds: lastPositionSeconds ?? this.lastPositionSeconds,
      lastSubtitleId: lastSubtitleId ?? this.lastSubtitleId,
      subtitleOffsetSeconds:
          subtitleOffsetSeconds ?? this.subtitleOffsetSeconds,
      subtitleAutoScrollEnabled:
          subtitleAutoScrollEnabled ?? this.subtitleAutoScrollEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'youtubeVideoId': youtubeVideoId,
      'url': url,
      'title': title,
      'thumbnailUrl': thumbnailUrl,
      'durationSeconds': durationSeconds,
      'subtitles': subtitles.map((line) => line.toJson()).toList(),
      'createdAt': createdAt.toIso8601String(),
      'lastPositionSeconds': lastPositionSeconds,
      'lastSubtitleId': lastSubtitleId,
      'subtitleOffsetSeconds': subtitleOffsetSeconds,
      'subtitleAutoScrollEnabled': subtitleAutoScrollEnabled,
    };
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    return VideoItem(
      id: json['id'] as String,
      youtubeVideoId: json['youtubeVideoId'] as String,
      url: json['url'] as String,
      title: json['title'] as String,
      thumbnailUrl: json['thumbnailUrl'] as String,
      durationSeconds: json['durationSeconds'] as int,
      subtitles: (json['subtitles'] as List<dynamic>)
          .map((item) => SubtitleLine.fromJson(item as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastPositionSeconds: (json['lastPositionSeconds'] as num?)?.toDouble() ?? 0,
      lastSubtitleId: json['lastSubtitleId'] as String?,
      subtitleOffsetSeconds:
          (json['subtitleOffsetSeconds'] as num?)?.toDouble() ?? 0,
      subtitleAutoScrollEnabled:
          json['subtitleAutoScrollEnabled'] as bool? ?? true,
    );
  }
}

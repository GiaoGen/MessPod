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
  });

  final String id;
  final String youtubeVideoId;
  final String url;
  final String title;
  final String thumbnailUrl;
  final int durationSeconds;
  final List<SubtitleLine> subtitles;
  final DateTime createdAt;

  VideoItem copyWith({List<SubtitleLine>? subtitles}) {
    return VideoItem(
      id: id,
      youtubeVideoId: youtubeVideoId,
      url: url,
      title: title,
      thumbnailUrl: thumbnailUrl,
      durationSeconds: durationSeconds,
      subtitles: subtitles ?? this.subtitles,
      createdAt: createdAt,
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
    );
  }
}

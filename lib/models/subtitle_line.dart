enum SubtitleStatus {
  unknown,
  understood,
  notUnderstood;

  static SubtitleStatus fromJson(String? value) {
    return SubtitleStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => SubtitleStatus.unknown,
    );
  }
}

class SubtitleLine {
  const SubtitleLine({
    required this.id,
    required this.videoId,
    required this.start,
    required this.duration,
    required this.text,
    this.status = SubtitleStatus.unknown,
  });

  final String id;
  final String videoId;
  final double start;
  final double duration;
  final String text;
  final SubtitleStatus status;

  double get end => start + duration;

  SubtitleLine copyWith({SubtitleStatus? status}) {
    return SubtitleLine(
      id: id,
      videoId: videoId,
      start: start,
      duration: duration,
      text: text,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'videoId': videoId,
      'start': start,
      'duration': duration,
      'end': end,
      'text': text,
      'status': status.name,
    };
  }

  factory SubtitleLine.fromJson(Map<String, dynamic> json) {
    return SubtitleLine(
      id: json['id'] as String,
      videoId: json['videoId'] as String,
      start: (json['start'] as num).toDouble(),
      duration: (json['duration'] as num).toDouble(),
      text: json['text'] as String,
      status: SubtitleStatus.fromJson(json['status'] as String?),
    );
  }
}

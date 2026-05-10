import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import '../models/vocabulary_item.dart';
import '../services/dictionary_service.dart';
import '../services/local_storage_service.dart';
import '../services/transcript_api_service.dart';
import '../services/youtube_service.dart';

class ParseStep {
  const ParseStep({
    required this.label,
    required this.index,
    required this.total,
  });

  final String label;
  final int index;
  final int total;

  double get progress => index / total;
}

class AppState extends ChangeNotifier {
  AppState({
    LocalStorageService? localStorageService,
    YoutubeService? youtubeService,
    DictionaryService? dictionaryService,
    TranscriptApiService? transcriptApiService,
  }) : _storage = localStorageService ?? LocalStorageService(),
       _youtube = youtubeService ?? YoutubeService(),
       _transcriptApi = transcriptApiService ?? TranscriptApiService(),
       dictionary = dictionaryService ?? DictionaryService() {
    load();
  }

  final LocalStorageService _storage;
  final YoutubeService _youtube;
  final TranscriptApiService _transcriptApi;
  final DictionaryService dictionary;
  final Uuid _uuid = const Uuid();

  List<VideoItem> _videos = [];
  List<VocabularyItem> _vocabularyItems = [];
  bool _isReady = false;

  List<VideoItem> get videos => List.unmodifiable(_videos);
  List<VocabularyItem> get vocabularyItems =>
      List.unmodifiable(_vocabularyItems);
  bool get isReady => _isReady;

  Future<void> load() async {
    _videos = await _storage.loadVideos();
    _vocabularyItems = await _storage.loadVocabulary();
    _isReady = true;
    notifyListeners();
  }

  Future<VideoItem> addVideoFromYoutubeUrl(
    String url, {
    ValueChanged<ParseStep>? onProgress,
  }) async {
    const steps = ['正在解析链接', '正在获取视频信息', '正在获取字幕', '正在保存', '完成'];

    void report(int index) {
      onProgress?.call(
        ParseStep(label: steps[index], index: index + 1, total: steps.length),
      );
    }

    report(0);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    final videoId = _youtube.extractVideoId(url);
    if (videoId == null) {
      throw FormatException('请输入有效的 YouTube 链接');
    }

    report(1);
    await Future<void>.delayed(const Duration(milliseconds: 120));

    report(2);
    final payload = await _transcriptApi.fetchVideo(videoId);
    if (payload.subtitles.isEmpty) {
      throw const TranscriptApiException('没有获取到字幕');
    }

    final videoLocalId = _uuid.v4();
    final subtitles = payload.subtitles.map((line) {
      return SubtitleLine(
        id: _uuid.v4(),
        videoId: videoLocalId,
        start: line.start,
        duration: line.duration,
        text: line.text,
      );
    }).toList();

    report(3);
    final video = VideoItem(
      id: videoLocalId,
      youtubeVideoId: videoId,
      url: url.trim(),
      title: payload.title,
      thumbnailUrl: _youtube.buildThumbnailUrl(videoId),
      durationSeconds: payload.durationSeconds,
      subtitles: subtitles,
      createdAt: DateTime.now(),
      lastPositionSeconds: 0,
      subtitleOffsetSeconds: 0,
      subtitleAutoScrollEnabled: true,
    );

    _videos = [video, ..._videos];
    await _storage.saveVideos(_videos);
    notifyListeners();

    report(4);
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return video;
  }

  VideoItem? findVideo(String videoId) {
    for (final video in _videos) {
      if (video.id == videoId) {
        return video;
      }
    }
    return null;
  }

  Future<void> removeVideo(String videoId) async {
    _videos = _videos.where((video) => video.id != videoId).toList();
    await _storage.saveVideos(_videos);
    notifyListeners();
  }

  Future<void> updateSubtitleStatus(
    String videoId,
    String subtitleId,
    SubtitleStatus status,
  ) async {
    _videos = _videos.map((video) {
      if (video.id != videoId) {
        return video;
      }

      final subtitles = video.subtitles.map((line) {
        if (line.id != subtitleId) {
          return line;
        }
        return line.copyWith(status: status);
      }).toList();

      return video.copyWith(subtitles: subtitles);
    }).toList();

    await _storage.saveVideos(_videos);
    notifyListeners();
  }

  Future<void> updateVideoPosition(
    String videoId,
    double positionSeconds, {
    String? subtitleId,
  }) async {
    _videos = _videos.map((video) {
      if (video.id != videoId) {
        return video;
      }
      return video.copyWith(
        lastPositionSeconds: positionSeconds,
        lastSubtitleId: subtitleId,
      );
    }).toList();

    await _storage.saveVideos(_videos);
  }

  Future<void> updateSubtitleOffset(
    String videoId,
    double offsetSeconds,
  ) async {
    _videos = _videos.map((video) {
      if (video.id != videoId) {
        return video;
      }
      return video.copyWith(
        subtitleOffsetSeconds: offsetSeconds.clamp(-5, 5).toDouble(),
      );
    }).toList();

    await _storage.saveVideos(_videos);
    notifyListeners();
  }

  Future<void> updateSubtitleAutoScroll(
    String videoId,
    bool enabled,
  ) async {
    _videos = _videos.map((video) {
      if (video.id != videoId) {
        return video;
      }
      return video.copyWith(subtitleAutoScrollEnabled: enabled);
    }).toList();

    await _storage.saveVideos(_videos);
    notifyListeners();
  }

  double calculateProgress(String videoId) {
    final video = findVideo(videoId);
    if (video == null || video.subtitles.isEmpty) {
      return 0;
    }

    final understood = video.subtitles
        .where((line) => line.status == SubtitleStatus.understood)
        .length;
    return understood / video.subtitles.length;
  }

  bool isVocabularySaved(String word, String sourceSubtitleText) {
    final normalized = word.toLowerCase();
    return _vocabularyItems.any(
      (item) =>
          item.word.toLowerCase() == normalized &&
          item.sourceSubtitleText == sourceSubtitleText,
    );
  }

  Future<bool> addOrRemoveVocabulary({
    required String word,
    required String sourceVideoId,
    required String sourceVideoTitle,
    required String sourceSubtitleText,
  }) async {
    final normalized = word.toLowerCase().trim();
    final existingIndex = _vocabularyItems.indexWhere(
      (item) =>
          item.word.toLowerCase() == normalized &&
          item.sourceSubtitleText == sourceSubtitleText,
    );

    if (existingIndex >= 0) {
      _vocabularyItems = [..._vocabularyItems]..removeAt(existingIndex);
      await _storage.saveVocabulary(_vocabularyItems);
      notifyListeners();
      return false;
    }

    final entry = dictionary.lookup(normalized);
    final item = VocabularyItem(
      id: _uuid.v4(),
      word: normalized,
      meaning: entry.meaning,
      sourceVideoId: sourceVideoId,
      sourceVideoTitle: sourceVideoTitle,
      sourceSubtitleText: sourceSubtitleText,
      createdAt: DateTime.now(),
    );

    _vocabularyItems = [item, ..._vocabularyItems];
    await _storage.saveVocabulary(_vocabularyItems);
    notifyListeners();
    return true;
  }

  Future<void> removeVocabulary(String id) async {
    _vocabularyItems = _vocabularyItems.where((item) => item.id != id).toList();
    await _storage.saveVocabulary(_vocabularyItems);
    notifyListeners();
  }
}

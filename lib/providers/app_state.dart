import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import '../models/vocabulary_item.dart';
import '../services/dictionary_service.dart';
import '../services/local_storage_service.dart';
import '../services/local_youtube_transcript_service.dart';
import '../services/transcript_payload.dart';
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
    LocalYoutubeTranscriptService? localTranscriptService,
  }) : _storage = localStorageService ?? LocalStorageService(),
       _youtube = youtubeService ?? YoutubeService(),
       _localTranscript =
           localTranscriptService ?? LocalYoutubeTranscriptService(),
       dictionary = dictionaryService ?? DictionaryService() {
    load();
  }

  final LocalStorageService _storage;
  final YoutubeService _youtube;
  final LocalYoutubeTranscriptService _localTranscript;
  final DictionaryService dictionary;
  final Uuid _uuid = const Uuid();

  List<VideoItem> _videos = [];
  List<VocabularyItem> _vocabularyItems = [];
  Map<String, int> _dailyStudySeconds = {};
  int _dailyTargetMinutes = 30;
  bool _isReady = false;
  bool _disposed = false;
  Timer? _videosSaveTimer;
  Timer? _vocabularySaveTimer;
  Timer? _statsSaveTimer;

  List<VideoItem> get videos => List.unmodifiable(_videos);
  List<VocabularyItem> get vocabularyItems =>
      List.unmodifiable(_vocabularyItems);
  Map<String, int> get dailyStudySeconds =>
      Map.unmodifiable(_dailyStudySeconds);
  int get dailyTargetMinutes => _dailyTargetMinutes;
  int get totalStudySeconds =>
      _dailyStudySeconds.values.fold(0, (total, seconds) => total + seconds);
  int get todayStudySeconds => studySecondsForDate(DateTime.now());
  bool get isReady => _isReady;

  Future<void> load() async {
    _videos = await _storage.loadVideos();
    _vocabularyItems = await _storage.loadVocabulary();
    _dailyStudySeconds = await _storage.loadDailyStudySeconds();
    _dailyTargetMinutes = (await _storage.loadDailyTargetMinutes())
        .clamp(5, 120)
        .toInt();
    if (_disposed) {
      return;
    }
    _isReady = true;
    notifyListeners();
    unawaited(_loadDictionary());
  }

  Future<void> _loadDictionary() async {
    try {
      await dictionary.load();
      if (!_disposed) {
        notifyListeners();
      }
    } catch (_) {
      // Dictionary availability should not block the main app shell.
    }
  }

  Future<VideoItem> addVideoFromYoutubeUrl(
    String url, {
    ValueChanged<ParseStep>? onProgress,
  }) async {
    const steps = ['正在解析链接', '正在获取视频信息', '正在本地解析字幕', '正在保存', '完成'];

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
    final payload = await _fetchTranscriptPayload(videoId);
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

  Future<TranscriptVideoPayload> _fetchTranscriptPayload(String videoId) async {
    try {
      return await _localTranscript.fetchVideo(videoId);
    } catch (error) {
      throw TranscriptApiException('本地字幕解析失败：$error');
    }
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
    var recordedSeconds = 0;
    _videos = _videos.map((video) {
      if (video.id != videoId) {
        return video;
      }

      final subtitles = video.subtitles.map((line) {
        if (line.id != subtitleId) {
          return line;
        }
        if (line.status == SubtitleStatus.unknown &&
            status != SubtitleStatus.unknown) {
          recordedSeconds = line.duration.round().clamp(1, 3600).toInt();
        }
        return line.copyWith(status: status);
      }).toList();

      return video.copyWith(subtitles: subtitles);
    }).toList();

    if (recordedSeconds > 0) {
      _addStudySeconds(recordedSeconds);
    }
    _scheduleSaveVideos();
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

    _scheduleSaveVideos();
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

    _scheduleSaveVideos();
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

    _scheduleSaveVideos();
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
    final normalized = dictionary.lookup(word).word.toLowerCase();
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
    final entry = dictionary.lookup(word);
    final normalized = entry.word.toLowerCase().trim();
    final existingIndex = _vocabularyItems.indexWhere(
      (item) =>
          item.word.toLowerCase() == normalized &&
          item.sourceSubtitleText == sourceSubtitleText,
    );

    if (existingIndex >= 0) {
      _vocabularyItems = [..._vocabularyItems]..removeAt(existingIndex);
      _scheduleSaveVocabulary();
      notifyListeners();
      return false;
    }

    final item = VocabularyItem(
      id: _uuid.v4(),
      word: normalized,
      meaning: entry.meaning,
      dictionarySource: entry.source,
      sourceVideoId: sourceVideoId,
      sourceVideoTitle: sourceVideoTitle,
      sourceSubtitleText: sourceSubtitleText,
      createdAt: DateTime.now(),
    );

    _vocabularyItems = [item, ..._vocabularyItems];
    _scheduleSaveVocabulary();
    notifyListeners();
    return true;
  }

  Future<void> removeVocabulary(String id) async {
    _vocabularyItems = _vocabularyItems.where((item) => item.id != id).toList();
    _scheduleSaveVocabulary();
    notifyListeners();
  }

  Future<DictionaryImportResult> importDictionaryFromFile(File file) async {
    final result = await dictionary.importFromFile(file);
    notifyListeners();
    return result;
  }

  int studySecondsForDate(DateTime date) {
    return _dailyStudySeconds[_dateKey(date)] ?? 0;
  }

  double progressForDate(DateTime date) {
    final targetSeconds = _dailyTargetMinutes * 60;
    if (targetSeconds <= 0) {
      return 0;
    }
    return (studySecondsForDate(date) / targetSeconds).clamp(0.0, 1.0);
  }

  Future<void> updateDailyTargetMinutes(int minutes) async {
    _dailyTargetMinutes = minutes.clamp(5, 120).toInt();
    await _storage.saveDailyTargetMinutes(_dailyTargetMinutes);
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _videosSaveTimer?.cancel();
    _vocabularySaveTimer?.cancel();
    _statsSaveTimer?.cancel();
    unawaited(_storage.saveVideos(_videos));
    unawaited(_storage.saveVocabulary(_vocabularyItems));
    unawaited(_storage.saveDailyStudySeconds(_dailyStudySeconds));
    super.dispose();
  }

  void _scheduleSaveVideos() {
    _videosSaveTimer?.cancel();
    _videosSaveTimer = Timer(const Duration(milliseconds: 650), () {
      unawaited(_storage.saveVideos(_videos));
    });
  }

  void _scheduleSaveVocabulary() {
    _vocabularySaveTimer?.cancel();
    _vocabularySaveTimer = Timer(const Duration(milliseconds: 350), () {
      unawaited(_storage.saveVocabulary(_vocabularyItems));
    });
  }

  void _addStudySeconds(int seconds) {
    final key = _dateKey(DateTime.now());
    _dailyStudySeconds = {
      ..._dailyStudySeconds,
      key: (_dailyStudySeconds[key] ?? 0) + seconds,
    };
    _scheduleSaveStats();
  }

  void _scheduleSaveStats() {
    _statsSaveTimer?.cancel();
    _statsSaveTimer = Timer(const Duration(milliseconds: 650), () {
      unawaited(_storage.saveDailyStudySeconds(_dailyStudySeconds));
    });
  }

  String _dateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

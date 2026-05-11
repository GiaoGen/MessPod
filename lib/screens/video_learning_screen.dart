import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import '../providers/app_state.dart';
import '../widgets/split_subtitle_overlay.dart';
import '../widgets/word_lookup_sheet.dart';
import '../widgets/youtube_mobile_webview.dart';

class VideoLearningScreen extends StatefulWidget {
  const VideoLearningScreen({super.key, required this.videoId});

  final String videoId;

  @override
  State<VideoLearningScreen> createState() => _VideoLearningScreenState();
}

class _VideoLearningScreenState extends State<VideoLearningScreen> {
  final ScrollController _subtitleController = ScrollController();
  final YoutubeWebPlaybackController _playbackController =
      YoutubeWebPlaybackController();
  final ValueNotifier<int> _currentIndexNotifier = ValueNotifier<int>(0);
  int _currentIndex = 0;
  bool _restoredPosition = false;
  String? _initializedVideoId;
  AppState? _appState;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _appState = context.read<AppState>();
    final video = _appState?.findVideo(widget.videoId);
    if (video == null || _initializedVideoId == video.id) {
      return;
    }

    _initializedVideoId = video.id;
    _setCurrentIndex(_indexForSavedSubtitle(video));
  }

  @override
  void dispose() {
    final appState = _appState;
    final video = appState?.findVideo(widget.videoId);
    if (appState != null && video != null && video.subtitles.isNotEmpty) {
      final line = video.subtitles[_boundedIndex(video)];
      unawaited(
        appState.updateVideoPosition(
          video.id,
          _positionForCurrentSubtitle(video),
          subtitleId: line.id,
        ),
      );
    }
    _subtitleController.dispose();
    _currentIndexNotifier.dispose();
    super.dispose();
  }

  void _syncSubtitle(Duration position) {
    final video = context.read<AppState>().findVideo(widget.videoId);
    if (video == null || video.subtitles.isEmpty) {
      return;
    }

    final seconds = position.inMilliseconds / 1000;
    if (!_restoredPosition) {
      _restoredPosition = true;
      if (video.lastPositionSeconds > 0.5) {
        _seekToSavedPosition(video);
        return;
      }
    }

    if (!video.subtitleAutoScrollEnabled) {
      return;
    }

    final subtitleSeconds = seconds + video.subtitleOffsetSeconds;
    final index = video.subtitles.indexWhere(
      (line) => subtitleSeconds >= line.start && subtitleSeconds < line.end,
    );
    final nextIndex = index >= 0 ? index : _currentIndex;
    if (nextIndex == _currentIndex || !mounted) {
      return;
    }

    _setCurrentIndex(nextIndex);
  }

  Future<void> _seekTo(SubtitleLine line) async {
    final appState = context.read<AppState>();
    final video = appState.findVideo(widget.videoId);
    final index =
        video?.subtitles.indexWhere((item) => item.id == line.id) ?? -1;
    final seekSeconds = (line.start - (video?.subtitleOffsetSeconds ?? 0))
        .clamp(0.0, double.infinity)
        .toDouble();
    await _playbackController.seekTo(seekSeconds);
    if (video != null) {
      unawaited(
        context.read<AppState>().updateVideoPosition(
          video.id,
          seekSeconds,
          subtitleId: line.id,
        ),
      );
    }
    if (index >= 0) {
      _setCurrentIndex(index);
    }
  }

  Future<void> _seekToSavedPosition(VideoItem video) async {
    await _playbackController.seekTo(video.lastPositionSeconds);
    final index = _indexForSavedSubtitle(video);
    _setCurrentIndex(index);
  }

  Future<void> _markUnderstood(VideoItem video) async {
    if (video.subtitles.isEmpty) {
      return;
    }

    final current = video.subtitles[_boundedIndex(video)];
    await context.read<AppState>().updateSubtitleStatus(
      video.id,
      current.id,
      SubtitleStatus.understood,
    );

    if (!video.subtitleAutoScrollEnabled) {
      final nextIndex = (_currentIndex + 1)
          .clamp(0, video.subtitles.length - 1)
          .toInt();
      _setCurrentIndex(nextIndex);
    }
  }

  Future<void> _markNotUnderstood(VideoItem video) async {
    if (video.subtitles.isEmpty) {
      return;
    }

    final current = video.subtitles[_boundedIndex(video)];
    await context.read<AppState>().updateSubtitleStatus(
      video.id,
      current.id,
      SubtitleStatus.notUnderstood,
    );
    await _playbackController.pause();
  }

  Future<void> _lookupWord(
    SubtitleLine line,
    String word,
    VideoItem video,
  ) async {
    await showWordLookupDialog(
      context: context,
      word: word,
      video: video,
      subtitleText: line.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final video = appState.findVideo(widget.videoId);

    if (video == null) {
      return const Scaffold(body: Center(child: Text('视频不存在')));
    }

    final progress = appState.calculateProgress(video.id);

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          Positioned.fill(
            child: YoutubeMobileWebView(
              videoId: video.youtubeVideoId,
              playbackController: _playbackController,
              onPositionChanged: _syncSubtitle,
            ),
          ),
          ValueListenableBuilder<int>(
            valueListenable: _currentIndexNotifier,
            builder: (context, currentIndex, _) {
              return SplitSubtitleOverlay(
                visible: true,
                video: video,
                progress: progress,
                percent: (progress * 100).round(),
                currentIndex: video.subtitles.isEmpty
                    ? 0
                    : _boundedIndexFor(video, currentIndex),
                subtitleController: _subtitleController,
                onLineTap: _seekTo,
                onWordTap: (line, word) => _lookupWord(line, word, video),
                onNotUnderstood: () => _markNotUnderstood(video),
                onUnderstood: () => _markUnderstood(video),
                onOffsetChanged: (offset) =>
                    appState.updateSubtitleOffset(video.id, offset),
                autoScrollEnabled: video.subtitleAutoScrollEnabled,
                onAutoScrollChanged: (enabled) =>
                    appState.updateSubtitleAutoScroll(video.id, enabled),
              );
            },
          ),
        ],
      ),
    );
  }

  int _boundedIndex(VideoItem video) {
    return _boundedIndexFor(video, _currentIndex);
  }

  int _boundedIndexFor(VideoItem video, int index) {
    if (video.subtitles.isEmpty) {
      return 0;
    }
    return index.clamp(0, video.subtitles.length - 1).toInt();
  }

  int _indexForPosition(VideoItem video, double positionSeconds) {
    if (video.subtitles.isEmpty) {
      return 0;
    }

    final subtitleSeconds = positionSeconds + video.subtitleOffsetSeconds;
    final activeIndex = video.subtitles.indexWhere(
      (line) => subtitleSeconds >= line.start && subtitleSeconds < line.end,
    );
    if (activeIndex >= 0) {
      return activeIndex;
    }

    final nextIndex = video.subtitles.indexWhere(
      (line) => line.start > subtitleSeconds,
    );
    if (nextIndex > 0) {
      return nextIndex - 1;
    }
    if (nextIndex == 0) {
      return 0;
    }
    return video.subtitles.length - 1;
  }

  int _indexForSavedSubtitle(VideoItem video) {
    final subtitleId = video.lastSubtitleId;
    if (subtitleId != null) {
      final index = video.subtitles.indexWhere((line) => line.id == subtitleId);
      if (index >= 0) {
        return index;
      }
    }

    return _indexForPosition(video, video.lastPositionSeconds);
  }

  double _positionForCurrentSubtitle(VideoItem video) {
    final index = _boundedIndex(video);
    final line = video.subtitles[index];
    return (line.start - video.subtitleOffsetSeconds)
        .clamp(0.0, double.infinity)
        .toDouble();
  }

  void _setCurrentIndex(int index) {
    if (_currentIndex == index) {
      return;
    }
    _currentIndex = index;
    if (mounted) {
      _currentIndexNotifier.value = index;
    }
  }
}

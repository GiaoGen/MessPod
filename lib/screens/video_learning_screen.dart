import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import '../providers/app_state.dart';
import '../widgets/bottom_understanding_controls.dart';
import '../widgets/progress_bar.dart';
import '../widgets/subtitle_list.dart';
import '../widgets/word_lookup_sheet.dart';
import '../widgets/youtube_player_widget.dart';

class VideoLearningScreen extends StatefulWidget {
  const VideoLearningScreen({super.key, required this.videoId});

  final String videoId;

  @override
  State<VideoLearningScreen> createState() => _VideoLearningScreenState();
}

class _VideoLearningScreenState extends State<VideoLearningScreen> {
  late final YoutubePlayerController _playerController;
  final ScrollController _subtitleController = ScrollController();
  StreamSubscription<YoutubeVideoState>? _positionSubscription;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    final video = context.read<AppState>().findVideo(widget.videoId);
    _playerController = YoutubePlayerController.fromVideoId(
      videoId: video?.youtubeVideoId ?? '',
      autoPlay: false,
      params: const YoutubePlayerParams(
        origin: 'https://www.youtube-nocookie.com',
        userAgent:
            'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
            '(KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
        interfaceLanguage: 'zh-CN',
        enableCaption: true,
        showControls: true,
        showFullscreenButton: true,
      ),
    );
    _positionSubscription = _playerController.videoStateStream.listen(
      (state) => _syncSubtitle(state.position),
    );
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _subtitleController.dispose();
    _playerController.close();
    super.dispose();
  }

  void _syncSubtitle(Duration position) {
    final video = context.read<AppState>().findVideo(widget.videoId);
    if (video == null || video.subtitles.isEmpty) {
      return;
    }

    final seconds = position.inMilliseconds / 1000;
    final index = video.subtitles.indexWhere(
      (line) => seconds >= line.start && seconds < line.end,
    );
    final nextIndex = index >= 0 ? index : _currentIndex;
    if (nextIndex == _currentIndex || !mounted) {
      return;
    }

    setState(() => _currentIndex = nextIndex);
    _scrollCurrentSubtitleIntoView(nextIndex);
  }

  void _scrollCurrentSubtitleIntoView(int index) {
    if (!_subtitleController.hasClients) {
      return;
    }

    final offset = (index * 112.0) - 160;
    _subtitleController.animateTo(
      offset.clamp(0, _subtitleController.position.maxScrollExtent).toDouble(),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _seekTo(SubtitleLine line) async {
    final appState = context.read<AppState>();
    await _playerController.seekTo(seconds: line.start, allowSeekAhead: true);
    await _playerController.playVideo();
    final video = appState.findVideo(widget.videoId);
    final index =
        video?.subtitles.indexWhere((item) => item.id == line.id) ?? -1;
    if (index >= 0 && mounted) {
      setState(() => _currentIndex = index);
      _scrollCurrentSubtitleIntoView(index);
    }
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

    final nextIndex = (_currentIndex + 1)
        .clamp(0, video.subtitles.length - 1)
        .toInt();
    final nextLine = video.subtitles[nextIndex];
    if (mounted) {
      setState(() => _currentIndex = nextIndex);
      _scrollCurrentSubtitleIntoView(nextIndex);
    }
    await _playerController.seekTo(
      seconds: nextLine.start,
      allowSeekAhead: true,
    );
    await _playerController.playVideo();
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
    await _playerController.pauseVideo();
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final video = appState.findVideo(widget.videoId);

    if (video == null) {
      return const Scaffold(body: Center(child: Text('视频不存在')));
    }

    final progress = appState.calculateProgress(video.id);
    final percent = (progress * 100).round();
    final currentIndex = video.subtitles.isEmpty ? 0 : _boundedIndex(video);

    return Scaffold(
      backgroundColor: const Color(0xFFF3EBDD),
      bottomNavigationBar: video.subtitles.isEmpty
          ? null
          : BottomUnderstandingControls(
              onNotUnderstood: () => _markNotUnderstood(video),
              onUnderstood: () => _markUnderstood(video),
            ),
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '返回',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  Expanded(
                    child: Text(
                      video.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3C2C20),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '在 YouTube 打开',
                    onPressed: () => launchUrl(
                      Uri.parse(video.url),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: YoutubePlayerWidget(controller: _playerController),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 4),
              child: Row(
                children: [
                  Expanded(child: ProgressBar(value: progress, height: 12)),
                  const SizedBox(width: 12),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Color(0xFF6E5139),
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SubtitleList(
                video: video,
                currentIndex: currentIndex,
                controller: _subtitleController,
                onLineTap: _seekTo,
                onWordTap: (word) {
                  if (video.subtitles.isEmpty) {
                    return;
                  }
                  final line = video.subtitles[currentIndex];
                  showWordLookupSheet(
                    context: context,
                    word: word,
                    video: video,
                    subtitleText: line.text,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _boundedIndex(VideoItem video) {
    if (video.subtitles.isEmpty) {
      return 0;
    }
    return _currentIndex.clamp(0, video.subtitles.length - 1).toInt();
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import '../providers/app_state.dart';
import '../widgets/progress_bar.dart';
import '../widgets/subtitle_list.dart';
import '../widgets/youtube_mobile_webview.dart';

class VideoLearningScreen extends StatefulWidget {
  const VideoLearningScreen({super.key, required this.videoId});

  final String videoId;

  @override
  State<VideoLearningScreen> createState() => _VideoLearningScreenState();
}

class _VideoLearningScreenState extends State<VideoLearningScreen> {
  final ScrollController _subtitleController = ScrollController();
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _subtitleController.dispose();
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
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.read<AppState>();
    final video = appState.findVideo(widget.videoId);

    if (video == null) {
      return const Scaffold(body: Center(child: Text('视频不存在')));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: YoutubeMobileWebView(videoId: video.youtubeVideoId),
    );
  }

  int _boundedIndex(VideoItem video) {
    if (video.subtitles.isEmpty) {
      return 0;
    }
    return _currentIndex.clamp(0, video.subtitles.length - 1).toInt();
  }
}

class HiddenSubtitleLearningPanel extends StatelessWidget {
  const HiddenSubtitleLearningPanel({
    super.key,
    required this.video,
    required this.progress,
    required this.percent,
    required this.currentIndex,
    required this.subtitleController,
    required this.onLineTap,
    required this.onWordTap,
  });

  final VideoItem video;
  final double progress;
  final int percent;
  final int currentIndex;
  final ScrollController subtitleController;
  final ValueChanged<SubtitleLine> onLineTap;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            controller: subtitleController,
            onLineTap: onLineTap,
            onWordTap: onWordTap,
          ),
        ),
      ],
    );
  }
}

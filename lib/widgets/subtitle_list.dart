import 'package:flutter/material.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import 'subtitle_line_widget.dart';

class SubtitleList extends StatelessWidget {
  const SubtitleList({
    super.key,
    required this.video,
    required this.currentIndex,
    required this.controller,
    required this.onLineTap,
    required this.onWordTap,
  });

  final VideoItem video;
  final int currentIndex;
  final ScrollController controller;
  final ValueChanged<SubtitleLine> onLineTap;
  final ValueChanged<String> onWordTap;

  @override
  Widget build(BuildContext context) {
    if (video.subtitles.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            '字幕服务待接入\n后续由 FastAPI 获取 YouTube Transcript',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7B6048),
              fontSize: 18,
              height: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
      itemCount: video.subtitles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final line = video.subtitles[index];
        return SubtitleLineWidget(
          line: line,
          isCurrent: index == currentIndex,
          onTap: () => onLineTap(line),
          onWordTap: onWordTap,
        );
      },
    );
  }
}

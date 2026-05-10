import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import 'subtitle_line_widget.dart';

typedef SubtitleWordTap = void Function(SubtitleLine line, String word);

class SubtitleList extends StatefulWidget {
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
  final SubtitleWordTap onWordTap;

  @override
  State<SubtitleList> createState() => _SubtitleListState();
}

class _SubtitleListState extends State<SubtitleList> {
  static const double _estimatedLineExtent = 132;

  final Map<String, GlobalKey> _lineKeys = {};
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;

  @override
  void initState() {
    super.initState();
    _scheduleEnsureCurrentVisible(animated: false);
  }

  @override
  void didUpdateWidget(SubtitleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _lineKeys.clear();
      _scheduleEnsureCurrentVisible(animated: false);
    } else if (oldWidget.currentIndex != widget.currentIndex) {
      _scheduleEnsureCurrentVisible();
    }
  }

  void _scheduleEnsureCurrentVisible({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureCurrentVisible(animated: animated);
    });
  }

  Future<void> _ensureCurrentVisible({bool animated = true}) async {
    if (!mounted || _isUserScrolling || widget.video.subtitles.isEmpty) {
      return;
    }
    if (!widget.controller.hasClients) {
      _scheduleEnsureCurrentVisible(animated: animated);
      return;
    }

    final index = widget.currentIndex.clamp(
      0,
      widget.video.subtitles.length - 1,
    ).toInt();
    final line = widget.video.subtitles[index];
    final context = _lineKeys[line.id]?.currentContext;
    if (context != null) {
      _isAutoScrolling = true;
      try {
        await Scrollable.ensureVisible(
          context,
          duration:
              animated ? const Duration(milliseconds: 220) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 0.5,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } finally {
        _isAutoScrolling = false;
      }
      return;
    }

    final position = widget.controller.position;
    final targetOffset =
        index * _estimatedLineExtent - position.viewportDimension * 0.45;
    final offset = targetOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _isAutoScrolling = true;
    try {
      if (animated) {
        await widget.controller.animateTo(
          offset,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      } else {
        widget.controller.jumpTo(offset);
      }
    } finally {
      _isAutoScrolling = false;
    }
  }

  GlobalKey _keyFor(SubtitleLine line) {
    return _lineKeys.putIfAbsent(line.id, GlobalKey.new);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.video.subtitles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            '字幕服务待接入\n后续由 FastAPI 获取 YouTube Transcript',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 18,
              height: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    }

    return NotificationListener<UserScrollNotification>(
      onNotification: (notification) {
        if (!_isAutoScrolling) {
          _isUserScrolling = notification.direction != ScrollDirection.idle;
        }
        return false;
      },
      child: ListView.separated(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        itemCount: widget.video.subtitles.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final line = widget.video.subtitles[index];
          return KeyedSubtree(
            key: _keyFor(line),
            child: SubtitleLineWidget(
              line: line,
              isCurrent: index == widget.currentIndex,
              onTap: () => widget.onLineTap(line),
              onWordTap: (word) => widget.onWordTap(line, word),
            ),
          );
        },
      ),
    );
  }
}

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
  static const double _minEstimatedLineExtent = 132;

  final GlobalKey _currentLineKey = GlobalKey();
  bool _isUserScrolling = false;
  bool _isAutoScrolling = false;
  int? _queuedScrollIndex;

  @override
  void initState() {
    super.initState();
    _scheduleEnsureCurrentVisible(animated: false);
  }

  @override
  void didUpdateWidget(SubtitleList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
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
    if (_isAutoScrolling) {
      _queuedScrollIndex = widget.currentIndex;
      return;
    }

    final index = widget.currentIndex.clamp(
      0,
      widget.video.subtitles.length - 1,
    ).toInt();
    final position = widget.controller.position;
    final currentContext = _currentLineKey.currentContext;
    if (currentContext != null) {
      _isAutoScrolling = true;
      try {
        await Scrollable.ensureVisible(
          currentContext,
          duration:
              animated ? const Duration(milliseconds: 140) : Duration.zero,
          curve: Curves.easeOutCubic,
          alignment: 0.35,
          alignmentPolicy: ScrollPositionAlignmentPolicy.explicit,
        );
      } finally {
        _isAutoScrolling = false;
        _flushQueuedScroll(index);
      }
      return;
    }

    final averageExtent =
        ((position.maxScrollExtent + position.viewportDimension) /
                widget.video.subtitles.length)
            .clamp(_minEstimatedLineExtent, 260.0)
            .toDouble();
    final targetOffset =
        index * averageExtent - position.viewportDimension * 0.35;
    final offset = targetOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();

    _isAutoScrolling = true;
    try {
      if (animated) {
        await widget.controller.animateTo(
          offset,
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
        );
      } else {
        widget.controller.jumpTo(offset);
      }
    } finally {
      _isAutoScrolling = false;
      _flushQueuedScroll(index);
      _scheduleCurrentContextCalibration();
    }
  }

  void _scheduleCurrentContextCalibration() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _isUserScrolling || _isAutoScrolling) {
        return;
      }
      if (_currentLineKey.currentContext != null) {
        _ensureCurrentVisible(animated: false);
      }
    });
  }

  void _flushQueuedScroll(int currentIndex) {
    if (_queuedScrollIndex != null && _queuedScrollIndex != currentIndex) {
      _queuedScrollIndex = null;
      _scheduleEnsureCurrentVisible();
    } else {
      _queuedScrollIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (widget.video.subtitles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            '暂无字幕\n请确认该视频有可用字幕',
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
          final isCurrent = index == widget.currentIndex;
          return KeyedSubtree(
            key: isCurrent ? _currentLineKey : ValueKey(line.id),
            child: SubtitleLineWidget(
              line: line,
              isCurrent: isCurrent,
              onTap: () => widget.onLineTap(line),
              onWordTap: (word) => widget.onWordTap(line, word),
            ),
          );
        },
      ),
    );
  }
}

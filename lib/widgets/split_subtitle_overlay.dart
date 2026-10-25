import 'package:flutter/material.dart';

import '../models/subtitle_line.dart';
import '../models/video_item.dart';
import 'bottom_understanding_controls.dart';
import 'progress_bar.dart';
import 'subtitle_list.dart';

class SplitSubtitleOverlay extends StatefulWidget {
  const SplitSubtitleOverlay({
    super.key,
    required this.visible,
    required this.video,
    required this.progress,
    required this.percent,
    required this.currentIndex,
    required this.subtitleController,
    required this.onLineTap,
    required this.onWordTap,
    required this.onNotUnderstood,
    required this.onUnderstood,
    required this.onOffsetChanged,
    required this.autoScrollEnabled,
    required this.onAutoScrollChanged,
    this.notUnderstoodIsResume = false,
    this.understoodIsResume = false,
  });

  final bool visible;
  final VideoItem video;
  final double progress;
  final int percent;
  final int currentIndex;
  final ScrollController subtitleController;
  final ValueChanged<SubtitleLine> onLineTap;
  final SubtitleWordTap onWordTap;
  final VoidCallback onNotUnderstood;
  final VoidCallback onUnderstood;
  final ValueChanged<double> onOffsetChanged;
  final bool autoScrollEnabled;
  final ValueChanged<bool> onAutoScrollChanged;
  final bool notUnderstoodIsResume;
  final bool understoodIsResume;

  static const double subtitleDrawerHeight = 413;
  static const double topLogoCoverHeight = 48;
  static const double controlsHeight = 82;

  @override
  State<SplitSubtitleOverlay> createState() => _SplitSubtitleOverlayState();
}

class _SplitSubtitleOverlayState extends State<SplitSubtitleOverlay> {
  bool _showSubtitleTools = false;

  void _handleHorizontalDrag(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -120) {
      setState(() => _showSubtitleTools = true);
    } else if (velocity > 120) {
      setState(() => _showSubtitleTools = false);
    }
  }

  void _changeOffset(double delta) {
    final next = (widget.video.subtitleOffsetSeconds + delta).clamp(-5.0, 5.0);
    widget.onOffsetChanged(double.parse(next.toStringAsFixed(1)));
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    final safeBottom = media.padding.bottom;
    final controlsTotalHeight =
        SplitSubtitleOverlay.controlsHeight + safeBottom;

    if (!widget.visible) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: SplitSubtitleOverlay.topLogoCoverHeight,
          child: Material(color: scheme.surface),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: controlsTotalHeight,
          height: SplitSubtitleOverlay.subtitleDrawerHeight,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragEnd: _handleHorizontalDrag,
            child: Material(
              color: scheme.surface,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: ProgressBar(value: widget.progress),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${widget.percent}%',
                              style: TextStyle(
                                color: scheme.primary,
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SubtitleList(
                          video: widget.video,
                          currentIndex: widget.currentIndex,
                          controller: widget.subtitleController,
                          onLineTap: widget.onLineTap,
                          onWordTap: widget.onWordTap,
                        ),
                      ),
                    ],
                  ),
                  if (_showSubtitleTools)
                    Positioned(
                      top: 48,
                      right: 14,
                      child: _SubtitleToolsPanel(
                        offset: widget.video.subtitleOffsetSeconds,
                        autoScrollEnabled: widget.autoScrollEnabled,
                        onAutoScrollChanged: widget.onAutoScrollChanged,
                        onDecrease: () => _changeOffset(-0.1),
                        onReset: () => widget.onOffsetChanged(0),
                        onIncrease: () => _changeOffset(0.1),
                        onClose: () =>
                            setState(() => _showSubtitleTools = false),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Material(
            color: scheme.surface,
            child: BottomUnderstandingControls(
              onNotUnderstood: widget.onNotUnderstood,
              onUnderstood: widget.onUnderstood,
              notUnderstoodLabel:
                  widget.notUnderstoodIsResume ? '▶ 继续播放' : '❌ 不懂',
              understoodLabel:
                  widget.understoodIsResume ? '▶ 继续播放' : '✅ 懂了',
            ),
          ),
        ),
      ],
    );
  }
}

class _SubtitleToolsPanel extends StatelessWidget {
  const _SubtitleToolsPanel({
    required this.offset,
    required this.autoScrollEnabled,
    required this.onAutoScrollChanged,
    required this.onDecrease,
    required this.onReset,
    required this.onIncrease,
    required this.onClose,
  });

  final double offset;
  final bool autoScrollEnabled;
  final ValueChanged<bool> onAutoScrollChanged;
  final VoidCallback onDecrease;
  final VoidCallback onReset;
  final VoidCallback onIncrease;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = offset == 0
        ? '0.0s'
        : offset > 0
        ? '+${offset.toStringAsFixed(1)}s'
        : offset.toStringAsFixed(1);

    return Material(
      color: scheme.surface,
      elevation: 10,
      shadowColor: scheme.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 248,
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '字幕控制',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '关闭',
                  visualDensity: VisualDensity.compact,
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                '自动滚动',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              value: autoScrollEnabled,
              onChanged: onAutoScrollChanged,
            ),
            Row(
              children: [
                IconButton.filledTonal(
                  tooltip: '字幕提前',
                  onPressed: onDecrease,
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: onReset,
                    child: Text(
                      '偏移 $label',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '字幕延后',
                  onPressed: onIncrease,
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

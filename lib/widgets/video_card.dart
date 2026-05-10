import 'package:flutter/material.dart';

import '../models/video_item.dart';
import 'progress_bar.dart';
import 'youtube_thumbnail.dart';

class VideoCard extends StatefulWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.progress,
    required this.onTap,
    required this.onDelete,
  });

  final VideoItem video;
  final double progress;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  State<VideoCard> createState() => _VideoCardState();
}

class _VideoCardState extends State<VideoCard> {
  static const double _deleteWidth = 92;
  bool _revealed = false;

  @override
  void didUpdateWidget(VideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id) {
      _revealed = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -80) {
      setState(() => _revealed = true);
    } else if (velocity > 80) {
      setState(() => _revealed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final percent = (widget.progress * 100).round();

    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        children: [
          if (_revealed)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              width: _deleteWidth,
              child: Material(
                color: scheme.errorContainer,
                child: InkWell(
                  onTap: widget.onDelete,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.delete_rounded,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '删除',
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              _revealed ? -_deleteWidth : 0,
              0,
              0,
            ),
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                if (details.delta.dx < -5 && !_revealed) {
                  setState(() => _revealed = true);
                } else if (details.delta.dx > 5 && _revealed) {
                  setState(() => _revealed = false);
                }
              },
              onHorizontalDragEnd: _handleDragEnd,
              child: Material(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(30),
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  onTap: _revealed
                      ? () => setState(() => _revealed = false)
                      : widget.onTap,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(alpha: 0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: YoutubeThumbnail(
                                videoId: widget.video.youtubeVideoId,
                                initialUrl: widget.video.thumbnailUrl,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            widget.video.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: scheme.onSurface,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: ProgressBar(value: widget.progress),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

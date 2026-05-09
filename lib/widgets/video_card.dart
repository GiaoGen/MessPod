import 'package:flutter/material.dart';

import '../models/video_item.dart';
import 'progress_bar.dart';

class VideoCard extends StatelessWidget {
  const VideoCard({
    super.key,
    required this.video,
    required this.progress,
    required this.onTap,
  });

  final VideoItem video;
  final double progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final percent = (progress * 100).round();

    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFAF1),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF5F4936).withValues(alpha: 0.08),
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
                  child: Image.network(
                    video.thumbnailUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) {
                      return Container(
                        color: const Color(0xFFE3D6C2),
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_circle_outline, size: 42),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                video.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF3C2C20),
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: ProgressBar(value: progress)),
                  const SizedBox(width: 12),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: Color(0xFF6E5139),
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
    );
  }
}

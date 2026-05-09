import 'package:flutter/material.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

class YoutubePlayerWidget extends StatelessWidget {
  const YoutubePlayerWidget({super.key, required this.controller});

  final YoutubePlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: YoutubeValueBuilder(
        controller: controller,
        buildWhen: (previous, current) => previous.error != current.error,
        builder: (context, value) {
          return Stack(
            alignment: Alignment.center,
            children: [
              YoutubePlayer(controller: controller, aspectRatio: 16 / 9),
              if (value.hasError)
                Positioned.fill(
                  child: Container(
                    color: const Color(0xFF3C2C20).withValues(alpha: 0.88),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFFFFAF1),
                          size: 34,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '播放器不可用（${value.error.code}）',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Color(0xFFFFFAF1),
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '这个视频可能限制了 iframe 嵌入播放',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFFD8C8B1),
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

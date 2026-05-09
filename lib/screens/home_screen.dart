import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/app_state.dart';
import '../widgets/video_card.dart';
import 'video_learning_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return SafeArea(
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 10),
              child: Text(
                '精听合集',
                style: TextStyle(
                  color: Color(0xFF3C2C20),
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          if (!appState.isReady)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (appState.videos.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(28),
                  child: Text(
                    '还没有视频\n点右下角添加 YouTube 链接',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF7B6048),
                      fontSize: 18,
                      height: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
              sliver: SliverList.separated(
                itemCount: appState.videos.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final video = appState.videos[index];
                  return VideoCard(
                    video: video,
                    progress: appState.calculateProgress(video.id),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              VideoLearningScreen(videoId: video.id),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

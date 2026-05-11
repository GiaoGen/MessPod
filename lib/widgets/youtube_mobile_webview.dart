import 'dart:async';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YoutubeWebPlaybackController {
  WebViewController? _controller;

  void _attach(WebViewController controller) {
    _controller = controller;
  }

  Future<void> play() async {
    await _runVideoCommand('''
      const video = document.querySelector("video");
      if (video) {
        video.muted = false;
        video.volume = 1;
        video.play();
      }
    ''');
  }

  Future<void> pause() async {
    await _runVideoCommand('document.querySelector("video")?.pause();');
  }

  Future<void> seekTo(double seconds) async {
    await _runVideoCommand('''
      (() => {
        const video = document.querySelector("video");
        if (!video) return false;
        video.muted = false;
        video.volume = 1;
        video.currentTime = $seconds;
        video.dispatchEvent(new Event("seeking"));
        video.dispatchEvent(new Event("timeupdate"));
        return true;
      })();
    ''');
  }

  Future<void> unmute() async {
    await _runVideoCommand('''
      const video = document.querySelector("video");
      if (video) {
        video.muted = false;
        video.volume = 1;
      }
    ''');
  }

  Future<double?> currentTime() async {
    final controller = _controller;
    if (controller == null) {
      return null;
    }

    try {
      final result = await controller.runJavaScriptReturningResult('''
        (() => {
          const video = document.querySelector("video");
          if (!video) return null;
          return video.currentTime;
        })();
      ''');
      if (result is num) {
        return result.toDouble();
      }
      return double.tryParse(result.toString());
    } catch (_) {
      return null;
    }
  }

  Future<void> _runVideoCommand(String command) async {
    final controller = _controller;
    if (controller == null) {
      return;
    }

    try {
      await controller.runJavaScript(command);
    } catch (_) {
      // The YouTube mobile page can replace its video node while loading.
    }
  }
}

class YoutubeMobileWebView extends StatefulWidget {
  const YoutubeMobileWebView({
    super.key,
    required this.videoId,
    required this.playbackController,
    required this.onPositionChanged,
  });

  final String videoId;
  final YoutubeWebPlaybackController playbackController;
  final ValueChanged<Duration> onPositionChanged;

  @override
  State<YoutubeMobileWebView> createState() => _YoutubeMobileWebViewState();
}

class _YoutubeMobileWebViewState extends State<YoutubeMobileWebView> {
  late final WebViewController _controller;
  Timer? _positionTimer;
  bool _positionRequestInFlight = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..loadRequest(_watchUri(widget.videoId));
    widget.playbackController._attach(_controller);
    _positionTimer = Timer.periodic(const Duration(milliseconds: 650), (_) {
      _emitCurrentPosition();
    });
  }

  @override
  void didUpdateWidget(YoutubeMobileWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadRequest(_watchUri(widget.videoId));
    }
    if (oldWidget.playbackController != widget.playbackController) {
      widget.playbackController._attach(_controller);
    }
  }

  @override
  void dispose() {
    _positionTimer?.cancel();
    super.dispose();
  }

  Future<void> _emitCurrentPosition() async {
    if (_positionRequestInFlight) {
      return;
    }
    _positionRequestInFlight = true;
    final seconds = await widget.playbackController.currentTime();
    _positionRequestInFlight = false;
    if (seconds == null || !mounted) {
      return;
    }
    widget.onPositionChanged(
      Duration(milliseconds: (seconds * 1000).round()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }

  static Uri _watchUri(String videoId) {
    return Uri.https('m.youtube.com', '/watch', {'v': videoId});
  }
}

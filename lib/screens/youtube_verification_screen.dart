import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YoutubeVerificationScreen extends StatefulWidget {
  const YoutubeVerificationScreen({super.key, this.videoId});

  final String? videoId;

  @override
  State<YoutubeVerificationScreen> createState() =>
      _YoutubeVerificationScreenState();
}

class _YoutubeVerificationScreenState extends State<YoutubeVerificationScreen> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(_youtubeUri(widget.videoId));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        title: const Text('YouTube 验证'),
      ),
      body: WebViewWidget(controller: _controller),
    );
  }

  static Uri _youtubeUri(String? videoId) {
    if (videoId == null || videoId.isEmpty) {
      return Uri.https('m.youtube.com', '/');
    }
    return Uri.https('m.youtube.com', '/watch', {'v': videoId});
  }
}

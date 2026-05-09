import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class YoutubeMobileWebView extends StatefulWidget {
  const YoutubeMobileWebView({
    super.key,
    required this.videoId,
  });

  final String videoId;

  @override
  State<YoutubeMobileWebView> createState() => _YoutubeMobileWebViewState();
}

class _YoutubeMobileWebViewState extends State<YoutubeMobileWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..loadRequest(_watchUri(widget.videoId));
  }

  @override
  void didUpdateWidget(YoutubeMobileWebView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _controller.loadRequest(_watchUri(widget.videoId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return WebViewWidget(controller: _controller);
  }

  static Uri _watchUri(String videoId) {
    return Uri.https('m.youtube.com', '/watch', {'v': videoId});
  }
}

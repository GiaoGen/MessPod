import 'package:flutter/material.dart';

class YoutubeThumbnail extends StatefulWidget {
  const YoutubeThumbnail({
    super.key,
    required this.videoId,
    required this.initialUrl,
  });

  final String videoId;
  final String initialUrl;

  @override
  State<YoutubeThumbnail> createState() => _YoutubeThumbnailState();
}

class _YoutubeThumbnailState extends State<YoutubeThumbnail> {
  static const _apiBaseUrl = String.fromEnvironment(
    'TRANSCRIPT_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  };

  late List<String> _urls;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _urls = _buildUrls();
  }

  @override
  void didUpdateWidget(YoutubeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.initialUrl != widget.initialUrl) {
      _urls = _buildUrls();
      _index = 0;
    }
  }

  List<String> _buildUrls() {
    final candidates = [
      '$_apiBaseUrl/videos/${widget.videoId}/thumbnail',
      widget.initialUrl,
      'https://i.ytimg.com/vi/${widget.videoId}/hqdefault.jpg',
      'https://i.ytimg.com/vi_webp/${widget.videoId}/hqdefault.webp',
      'https://i.ytimg.com/vi/${widget.videoId}/mqdefault.jpg',
      'https://img.youtube.com/vi/${widget.videoId}/0.jpg',
    ].where((url) => url.trim().isNotEmpty).toList();

    return candidates.toSet().toList();
  }

  void _tryNext() {
    if (_index >= _urls.length - 1) {
      return;
    }
    setState(() => _index += 1);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (_urls.isEmpty) {
      return _Placeholder(scheme: scheme);
    }

    return Image.network(
      _urls[_index],
      key: ValueKey(_urls[_index]),
      headers: _headers,
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          return child;
        }
        return _Placeholder(
          scheme: scheme,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (_, _, _) {
        if (_index < _urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _tryNext());
          return _Placeholder(
            scheme: scheme,
            child: const CircularProgressIndicator(),
          );
        }
        return _Placeholder(scheme: scheme);
      },
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({
    required this.scheme,
    this.child,
  });

  final ColorScheme scheme;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: scheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child:
          child ??
          Icon(
            Icons.play_circle_outline,
            color: scheme.onSurfaceVariant,
            size: 42,
          ),
    );
  }
}

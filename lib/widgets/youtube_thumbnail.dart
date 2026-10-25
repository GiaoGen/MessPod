import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  static const _directoryChannel = MethodChannel('ytpodcast/app_dirs');

  static const _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
  };

  late List<String> _urls;
  File? _cachedFile;
  int _index = 0;
  bool _isCaching = false;

  @override
  void initState() {
    super.initState();
    _urls = _buildUrls();
    unawaited(_loadCachedFile());
  }

  @override
  void didUpdateWidget(YoutubeThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.initialUrl != widget.initialUrl) {
      _urls = _buildUrls();
      _cachedFile = null;
      _index = 0;
      _isCaching = false;
      unawaited(_loadCachedFile());
    }
  }

  List<String> _buildUrls() {
    final candidates = [
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

    final cachedFile = _cachedFile;
    if (cachedFile != null) {
      return Image.file(
        cachedFile,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => _NetworkThumbnail(
          url: _urls[_index],
          headers: _headers,
          scheme: scheme,
          canRetry: _index < _urls.length - 1,
          onLoaded: () => _cacheCurrentThumbnail(),
          onError: _tryNext,
        ),
      );
    }

    return _NetworkThumbnail(
      url: _urls[_index],
      headers: _headers,
      scheme: scheme,
      canRetry: _index < _urls.length - 1,
      onLoaded: () => _cacheCurrentThumbnail(),
      onError: _tryNext,
    );
  }

  Future<void> _loadCachedFile() async {
    final file = await _thumbnailFile();
    if (!mounted || file == null || !await file.exists()) {
      return;
    }
    setState(() => _cachedFile = file);
  }

  Future<File?> _thumbnailFile() async {
    try {
      final root = await _directoryChannel.invokeMethod<String>(
        'documentsPath',
      );
      if (root == null || root.isEmpty) {
        return null;
      }
      final directory = Directory('$root/thumbnails');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return File('${directory.path}/${widget.videoId}.jpg');
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheCurrentThumbnail() async {
    if (_isCaching || _cachedFile != null || _urls.isEmpty) {
      return;
    }
    _isCaching = true;
    try {
      final file = await _thumbnailFile();
      if (file == null || await file.exists()) {
        return;
      }

      final client = HttpClient();
      try {
        final request = await client.getUrl(Uri.parse(_urls[_index]));
        _headers.forEach(request.headers.add);
        final response = await request.close();
        if (response.statusCode < 200 || response.statusCode >= 300) {
          return;
        }
        final bytes = await consolidateHttpClientResponseBytes(response);
        await file.writeAsBytes(bytes, flush: false);
        if (mounted) {
          setState(() => _cachedFile = file);
        }
      } finally {
        client.close(force: true);
      }
    } catch (_) {
      // Thumbnail cache is an optimization only.
    } finally {
      _isCaching = false;
    }
  }
}

class _NetworkThumbnail extends StatelessWidget {
  const _NetworkThumbnail({
    required this.url,
    required this.headers,
    required this.scheme,
    required this.canRetry,
    required this.onLoaded,
    required this.onError,
  });

  final String url;
  final Map<String, String> headers;
  final ColorScheme scheme;
  final bool canRetry;
  final VoidCallback onLoaded;
  final VoidCallback onError;

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      key: ValueKey(url),
      headers: headers,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onLoaded());
          return child;
        }
        return _Placeholder(
          scheme: scheme,
          child: const CircularProgressIndicator(),
        );
      },
      errorBuilder: (_, _, _) {
        if (!canRetry) {
          return _Placeholder(scheme: scheme);
        }
        WidgetsBinding.instance.addPostFrameCallback((_) => onError());
        return _Placeholder(
          scheme: scheme,
          child: const CircularProgressIndicator(),
        );
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

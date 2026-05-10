class YoutubeService {
  String? extractVideoId(String url) {
    final input = url.trim();
    if (input.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(input);
    if (uri != null && uri.host.isNotEmpty) {
      final host = uri.host.toLowerCase().replaceFirst('www.', '');

      if (host == 'youtu.be' && uri.pathSegments.isNotEmpty) {
        return _normalizeId(uri.pathSegments.first);
      }

      if (host.endsWith('youtube.com') ||
          host.endsWith('youtube-nocookie.com')) {
        final watchId = uri.queryParameters['v'];
        if (watchId != null) {
          return _normalizeId(watchId);
        }

        if (uri.pathSegments.length >= 2 &&
            ['embed', 'shorts', 'live'].contains(uri.pathSegments.first)) {
          return _normalizeId(uri.pathSegments[1]);
        }
      }
    }

    final fallback = RegExp(r'([a-zA-Z0-9_-]{11})').firstMatch(input);
    return fallback == null ? null : _normalizeId(fallback.group(1)!);
  }

  String buildThumbnailUrl(String videoId) {
    return 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';
  }

  String? _normalizeId(String value) {
    final id = value.trim();
    return RegExp(r'^[a-zA-Z0-9_-]{11}$').hasMatch(id) ? id : null;
  }
}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'transcript_payload.dart';

class LocalYoutubeTranscriptService {
  LocalYoutubeTranscriptService({HttpClient? client})
      : _client = client ?? HttpClient();

  static const _watchUrl = 'https://www.youtube.com/watch?v=';
  static const _innertubeUrl = 'https://www.youtube.com/youtubei/v1/player';
  static const _clientContext = {
    'client': {
      'clientName': 'ANDROID',
      'clientVersion': '20.10.38',
    },
  };
  static const _preferredLanguages = ['en', 'en-US', 'en-GB', 'zh-Hans'];
  static const _minimumWordsPerLine = 5;
  static final _apiKeyPattern = RegExp(
    r'"INNERTUBE_API_KEY"\s*:\s*"([a-zA-Z0-9_-]+)"',
  );
  static final _textNodePattern = RegExp(
    r'<text\b([^>]*)>(.*?)<\/text>',
    dotAll: true,
  );
  static final _startPattern = RegExp(r'\bstart="([^"]+)"');
  static final _durationPattern = RegExp(r'\bdur="([^"]+)"');
  static final _htmlTagPattern = RegExp(r'<[^>]*>');
  static final _sentencePartPattern = RegExp(
    r'''.+?[.!?\u3002\uff01\uff1f]+["'\u201d\u2019)\]]*|.+$''',
  );
  static final _sentenceEndPattern = RegExp(
    r'''[.!?\u3002\uff01\uff1f]+["'\u201d\u2019)\]]*$''',
  );

  final HttpClient _client;

  Future<TranscriptVideoPayload> fetchVideo(String videoId) async {
    try {
      final html = await _fetchWatchHtml(videoId);
      final apiKey = _extractInnertubeApiKey(html);
      final playerJson = await _fetchPlayerJson(videoId, apiKey);
      final title = _extractTitle(playerJson, videoId);
      final durationSeconds = _extractDuration(playerJson);
      final captionTrack = _selectCaptionTrack(playerJson);
      final transcriptXml = await _fetchText(captionTrack.baseUrl, label: '字幕 XML');
      final rawLines = _parseTranscriptXml(transcriptXml);
      final subtitles = _mergeTranscriptLines(rawLines);

      if (subtitles.isEmpty) {
        throw const TranscriptApiException('本地解析没有获取到字幕');
      }

      return TranscriptVideoPayload(
        title: title,
        durationSeconds: durationSeconds,
        subtitles: subtitles,
      );
    } on TranscriptApiException {
      rethrow;
    } catch (error) {
      throw TranscriptApiException('本地解析异常：$error');
    }
  }

  Future<String> _fetchWatchHtml(String videoId) async {
    final html = await _fetchText('$_watchUrl$videoId', label: 'watch 页面');
    if (html.contains('class="g-recaptcha"')) {
      throw const TranscriptApiException('YouTube 请求被拦截');
    }
    return html;
  }

  String _extractInnertubeApiKey(String html) {
    final match = _apiKeyPattern.firstMatch(html);
    if (match == null) {
      throw const TranscriptApiException('无法解析 YouTube API key');
    }
    return match.group(1)!;
  }

  Future<Map<String, dynamic>> _fetchPlayerJson(
    String videoId,
    String apiKey,
  ) async {
    final uri = Uri.parse('$_innertubeUrl?key=$apiKey');
    late final HttpClientResponse response;
    late final String body;
    try {
      final request = await _client.postUrl(uri).timeout(
        const Duration(seconds: 15),
      );
      _applyHeaders(request);
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode({
          'context': _clientContext,
          'videoId': videoId,
        }),
      );
      response = await request.close().timeout(const Duration(seconds: 15));
      body = await utf8.decodeStream(response).timeout(
        const Duration(seconds: 15),
      );
    } catch (error) {
      throw TranscriptApiException('请求 YouTube player API 失败：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranscriptApiException(
        'YouTube player API failed (${response.statusCode})',
      );
    }
    final decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const TranscriptApiException('YouTube player API 返回异常');
    }
    _assertPlayable(decoded);
    return decoded;
  }

  void _assertPlayable(Map<String, dynamic> playerJson) {
    final status = playerJson['playabilityStatus'];
    if (status is! Map<String, dynamic>) {
      return;
    }
    final value = status['status'] as String?;
    if (value == null || value == 'OK') {
      return;
    }
    final reason = (status['reason'] as String?) ?? '视频不可播放';
    if (value == 'LOGIN_REQUIRED') {
      throw TranscriptApiException('需要登录或验证：$reason');
    }
    throw TranscriptApiException(reason);
  }

  String _extractTitle(Map<String, dynamic> playerJson, String videoId) {
    final details = playerJson['videoDetails'];
    if (details is Map<String, dynamic>) {
      final title = (details['title'] as String?)?.trim();
      if (title != null && title.isNotEmpty) {
        return title;
      }
    }
    return 'YouTube video - $videoId';
  }

  int _extractDuration(Map<String, dynamic> playerJson) {
    final details = playerJson['videoDetails'];
    if (details is Map<String, dynamic>) {
      final raw = details['lengthSeconds'];
      if (raw is num) {
        return raw.round();
      }
      if (raw is String) {
        return int.tryParse(raw) ?? 0;
      }
    }
    return 0;
  }

  _CaptionTrack _selectCaptionTrack(Map<String, dynamic> playerJson) {
    final captions = playerJson['captions'];
    final renderer = captions is Map<String, dynamic>
        ? captions['playerCaptionsTracklistRenderer']
        : null;
    final tracks = renderer is Map<String, dynamic>
        ? renderer['captionTracks']
        : null;
    if (tracks is! List || tracks.isEmpty) {
      throw const TranscriptApiException('该视频没有可用字幕');
    }

    final captionTracks = tracks
        .whereType<Map<String, dynamic>>()
        .map(_CaptionTrack.fromJson)
        .where((track) => track.baseUrl.isNotEmpty)
        .toList();
    if (captionTracks.isEmpty) {
      throw const TranscriptApiException('该视频没有可用字幕');
    }

    for (final language in _preferredLanguages) {
      final manual = _findTrack(
        captionTracks,
        language,
        generated: false,
      );
      if (manual != null) {
        return manual;
      }
    }
    for (final language in _preferredLanguages) {
      final generated = _findTrack(
        captionTracks,
        language,
        generated: true,
      );
      if (generated != null) {
        return generated;
      }
    }
    return captionTracks.first;
  }

  _CaptionTrack? _findTrack(
    List<_CaptionTrack> tracks,
    String language, {
    required bool generated,
  }) {
    for (final track in tracks) {
      if (track.languageCode == language && track.isGenerated == generated) {
        return track;
      }
    }
    return null;
  }

  List<TranscriptLinePayload> _parseTranscriptXml(String rawXml) {
    final lines = <TranscriptLinePayload>[];
    for (final match in _textNodePattern.allMatches(rawXml)) {
      final attributes = match.group(1) ?? '';
      final rawText = match.group(2) ?? '';
      final start = double.tryParse(
        _startPattern.firstMatch(attributes)?.group(1) ?? '',
      );
      final duration = double.tryParse(
        _durationPattern.firstMatch(attributes)?.group(1) ?? '',
      );
      if (start == null || duration == null) {
        continue;
      }
      final text = _normalizeSubtitleText(rawText);
      if (text.isEmpty) {
        continue;
      }
      lines.add(
        TranscriptLinePayload(
          start: start,
          duration: duration,
          text: text,
        ),
      );
    }
    return lines;
  }

  List<TranscriptLinePayload> _mergeTranscriptLines(
    List<TranscriptLinePayload> transcript,
  ) {
    final lines = <TranscriptLinePayload>[];
    final currentText = <String>[];
    double? currentStart;
    double? currentEnd;

    for (final snippet in transcript) {
      final parts = _splitTextBySentenceEnd(snippet.text);
      if (parts.isEmpty) {
        continue;
      }

      final start = snippet.start;
      final end = snippet.start + snippet.duration;
      for (var index = 0; index < parts.length; index += 1) {
        final part = parts[index];
        final partStart = index == 0 ? start : currentEnd ?? start;
        final partEnd = _estimatePartEnd(start, end, parts, index);
        currentStart ??= partStart;
        currentEnd = partEnd;
        currentText.add(part);

        if (_sentenceEndPattern.hasMatch(part) &&
            _wordCount(currentText.join(' ')) >= _minimumWordsPerLine) {
          _appendMergedLine(lines, currentStart, currentEnd, currentText);
          currentStart = null;
          currentEnd = null;
          currentText.clear();
        }
      }
    }

    if (currentText.isNotEmpty) {
      _appendMergedLine(lines, currentStart, currentEnd, currentText);
    }
    return lines;
  }

  List<String> _splitTextBySentenceEnd(String text) {
    return _sentencePartPattern
        .allMatches(text)
        .map((match) => match.group(0)?.trim() ?? '')
        .where((part) => part.isNotEmpty)
        .toList();
  }

  double _estimatePartEnd(
    double start,
    double end,
    List<String> parts,
    int index,
  ) {
    if (parts.length <= 1) {
      return end;
    }
    final totalChars = parts.fold<int>(
      0,
      (total, part) => total + part.length.clamp(1, 1 << 20).toInt(),
    );
    final elapsedChars = parts.take(index + 1).fold<int>(
      0,
      (total, part) => total + part.length.clamp(1, 1 << 20).toInt(),
    );
    return start + ((end - start) * (elapsedChars / totalChars));
  }

  void _appendMergedLine(
    List<TranscriptLinePayload> lines,
    double? start,
    double? end,
    List<String> textParts,
  ) {
    if (start == null || end == null) {
      return;
    }
    final text = textParts.join(' ').trim();
    if (text.isEmpty) {
      return;
    }
    lines.add(
      TranscriptLinePayload(
        start: start,
        duration: (end - start).clamp(0.1, double.infinity).toDouble(),
        text: text,
      ),
    );
  }

  int _wordCount(String text) {
    return RegExp(r"[A-Za-z0-9]+(?:[-'][A-Za-z0-9]+)?")
        .allMatches(text)
        .length;
  }

  Future<String> _fetchText(String url, {required String label}) async {
    late final HttpClientResponse response;
    late final String body;
    try {
      final request = await _client.getUrl(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );
      _applyHeaders(request);
      response = await request.close().timeout(const Duration(seconds: 15));
      body = await utf8.decodeStream(response).timeout(
        const Duration(seconds: 15),
      );
    } catch (error) {
      throw TranscriptApiException('请求 $label 失败：$error');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw TranscriptApiException(
        '请求 $label 失败 (${response.statusCode})',
      );
    }
    return body;
  }

  void _applyHeaders(HttpClientRequest request) {
    request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US');
    request.headers.set(
      HttpHeaders.userAgentHeader,
      'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36',
    );
  }

  String _normalizeSubtitleText(String value) {
    return _htmlDeepUnescape(value)
        .replaceAll(_htmlTagPattern, '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _htmlDeepUnescape(String value) {
    var decoded = value;
    for (var i = 0; i < 3; i += 1) {
      final next = _htmlUnescape(decoded);
      if (next == decoded) {
        break;
      }
      decoded = next;
    }
    return decoded;
  }

  String _htmlUnescape(String value) {
    return value
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&nbsp;', ' ');
  }
}

class _CaptionTrack {
  const _CaptionTrack({
    required this.baseUrl,
    required this.languageCode,
    required this.isGenerated,
  });

  final String baseUrl;
  final String languageCode;
  final bool isGenerated;

  factory _CaptionTrack.fromJson(Map<String, dynamic> json) {
    final rawBaseUrl = (json['baseUrl'] as String?) ?? '';
    return _CaptionTrack(
      baseUrl: rawBaseUrl.replaceAll('&fmt=srv3', ''),
      languageCode: (json['languageCode'] as String?) ?? '',
      isGenerated: json['kind'] == 'asr',
    );
  }
}

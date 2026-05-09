import 'package:flutter_test/flutter_test.dart';

import 'package:ytpodcast/services/youtube_service.dart';

void main() {
  test('extracts YouTube video ids from common URLs', () {
    final service = YoutubeService();

    expect(
      service.extractVideoId('https://www.youtube.com/watch?v=dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      service.extractVideoId('https://youtu.be/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
    expect(
      service.extractVideoId('https://www.youtube.com/shorts/dQw4w9WgXcQ'),
      'dQw4w9WgXcQ',
    );
  });
}

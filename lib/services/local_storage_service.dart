import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/video_item.dart';
import '../models/vocabulary_item.dart';

class LocalStorageService {
  static const _videosKey = 'videos';
  static const _vocabularyKey = 'vocabulary';
  static const _dailyStudySecondsKey = 'dailyStudySeconds';
  static const _dailyTargetMinutesKey = 'dailyTargetMinutes';

  Future<List<VideoItem>> loadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_videosKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .map((item) => VideoItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveVideos(List<VideoItem> videos) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _videosKey,
      jsonEncode(videos.map((video) => video.toJson()).toList()),
    );
  }

  Future<List<VocabularyItem>> loadVocabulary() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_vocabularyKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final items = jsonDecode(raw) as List<dynamic>;
    return items
        .map((item) => VocabularyItem.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<void> saveVocabulary(List<VocabularyItem> vocabulary) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _vocabularyKey,
      jsonEncode(vocabulary.map((item) => item.toJson()).toList()),
    );
  }

  Future<Map<String, int>> loadDailyStudySeconds() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_dailyStudySecondsKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map(
      (key, value) => MapEntry(key, (value as num).round()),
    );
  }

  Future<void> saveDailyStudySeconds(Map<String, int> secondsByDate) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyStudySecondsKey, jsonEncode(secondsByDate));
  }

  Future<int> loadDailyTargetMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dailyTargetMinutesKey) ?? 30;
  }

  Future<void> saveDailyTargetMinutes(int minutes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyTargetMinutesKey, minutes);
  }
}

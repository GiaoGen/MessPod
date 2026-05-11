import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class DictionaryEntry {
  const DictionaryEntry({
    required this.word,
    required this.meaning,
    required this.fullMeaning,
    this.headword,
    this.phonetic,
    this.html,
    this.source,
    this.isLocal = false,
  });

  final String word;
  final String? headword;
  final String meaning;
  final String fullMeaning;
  final String? phonetic;
  final String? html;
  final String? source;
  final bool isLocal;
}

class DictionaryImportResult {
  const DictionaryImportResult({
    required this.name,
    required this.entryCount,
    required this.skippedCount,
  });

  final String name;
  final int entryCount;
  final int skippedCount;
}

class DictionaryFormatException implements Exception {
  const DictionaryFormatException(this.message);

  final String message;

  @override
  String toString() => message;
}

class DictionaryService {
  static const _directoryChannel = MethodChannel('ytpodcast/app_dirs');
  static const _entriesFileName = 'entries.jsonl';
  static const _indexFileName = 'index.json';
  static const _manifestFileName = 'manifest.json';
  static const _importYieldEvery = 300;

  static const Map<String, String> _meanings = {
    'hello': '你好',
    'world': '世界',
    'learn': '学习',
    'language': '语言',
    'understand': '理解',
  };

  final Map<String, int> _index = {};
  final Map<String, DictionaryEntry> _lookupCache = {};
  Directory? _dictionaryDirectory;
  String? _dictionaryName;
  int? _dictionaryEntryCount;

  bool get hasLocalDictionary => _index.isNotEmpty;
  String? get localDictionaryName => _dictionaryName;
  int get localEntryCount => _dictionaryEntryCount ?? _index.length;

  Future<void> load() async {
    final directory = await _resolveDictionaryDirectory();
    final indexFile = File('${directory.path}/$_indexFileName');
    final manifestFile = File('${directory.path}/$_manifestFileName');

    _index.clear();
    _lookupCache.clear();
    if (await indexFile.exists()) {
      await _loadIndexFile(indexFile);
    }

    if (await manifestFile.exists()) {
      final manifest =
          jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
      _dictionaryName = manifest['name'] as String?;
      final entryCount = manifest['entryCount'];
      _dictionaryEntryCount = entryCount is num ? entryCount.toInt() : null;
    }
  }

  DictionaryEntry lookup(String word) {
    final normalized = normalizeWord(word);
    if (normalized.isEmpty) {
      return _fallbackEntry(word);
    }

    for (final candidate in _lookupCandidates(normalized)) {
      final cached = _lookupCache[candidate] ?? _lookupCache[normalized];
      if (cached != null) {
        return cached;
      }

      final local = _lookupLocal(candidate);
      if (local != null) {
        _cacheLookup(normalized, local);
        if (candidate != normalized) {
          _cacheLookup(candidate, local);
        }
        return local;
      }
    }

    return _fallbackEntry(normalized);
  }

  Future<DictionaryImportResult> importFromFile(File file) async {
    final extension = _extensionOf(file.path);
    if (extension == '.jsonl' ||
        extension == '.tab' ||
        extension == '.tsv' ||
        extension == '.csv') {
      return _importTextLines(
        file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
        name: _basenameWithoutExtension(file.path),
      );
    }
    if (extension == '.dict' ||
        (extension == '.txt' && await _fileLooksDelimited(file))) {
      return _importDelimitedLines(
        file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
        name: _basenameWithoutExtension(file.path),
      );
    }
    if (extension == '.txt') {
      return _importTextLines(
        file.openRead().transform(utf8.decoder).transform(const LineSplitter()),
        name: _basenameWithoutExtension(file.path),
      );
    }

    final bytes = await file.readAsBytes();
    return importFromBytes(bytes, filename: _basename(file.path));
  }

  Future<bool> _fileLooksDelimited(File file) async {
    try {
      final sample = await file
          .openRead(0, 64 * 1024)
          .transform(utf8.decoder)
          .join();
      return _looksLikeDelimitedDictionary(sample);
    } catch (_) {
      return false;
    }
  }

  Future<DictionaryImportResult> importFromBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    final extension = _extensionOf(filename);

    if (extension == '.json') {
      final raw = utf8.decode(bytes);
      final decoded = jsonDecode(raw);
      return _importJsonValue(
        decoded,
        name: _basenameWithoutExtension(filename),
      );
    }

    try {
      final raw = utf8.decode(bytes);
      final trimmed = raw.trimLeft();
      if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
        return _importJsonValue(
          jsonDecode(raw),
          name: _basenameWithoutExtension(filename),
        );
      }

      if (_looksLikeDelimitedDictionary(raw)) {
        return _importDelimitedText(raw, name: _basenameWithoutExtension(filename));
      }

      final lines = const LineSplitter().convert(raw);
      return _importTextLines(
        Stream<String>.fromIterable(lines),
        name: _basenameWithoutExtension(filename),
      );
    } catch (_) {
      throw const DictionaryFormatException(
        '无法解析词典。建议从 PyGlossary 导出 Tabfile、CSV、JSON 或 JSON Lines。',
      );
    }
  }

  DictionaryEntry? _lookupLocal(String normalized) {
    final offset = _index[normalized];
    final directory = _dictionaryDirectory;
    if (offset == null || directory == null) {
      return null;
    }

    final entriesFile = File('${directory.path}/$_entriesFileName');
    if (!entriesFile.existsSync()) {
      return null;
    }

    final reader = entriesFile.openSync();
    try {
      reader.setPositionSync(offset);
      final bytes = <int>[];
      while (true) {
        final byte = reader.readByteSync();
        if (byte == -1 || byte == 10) {
          break;
        }
        bytes.add(byte);
      }

      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      final record = _DictionaryRecord.fromJson(json);
      return record.toEntry(source: _dictionaryName);
    } catch (_) {
      return null;
    } finally {
      reader.closeSync();
    }
  }

  Future<DictionaryImportResult> _importTextLines(
    Stream<String> lines, {
    required String name,
  }) async {
    return _importLineRecords(
      lines,
      name: name,
      parser: _parseFlexibleTextLine,
    );
  }

  Future<DictionaryImportResult> _importDelimitedText(
    String raw, {
    required String name,
  }) {
    return _importDelimitedLines(
      Stream<String>.fromIterable(const LineSplitter().convert(raw)),
      name: name,
    );
  }

  Future<DictionaryImportResult> _importDelimitedLines(
    Stream<String> lines, {
    required String name,
  }) async {
    return _writeRecordStream(
      _readDelimitedRecords(lines),
      name: name,
      skippedCount: 0,
    );
  }

  Stream<_DictionaryRecord> _readDelimitedRecords(Stream<String> lines) async* {
    final blockLines = <String>[];
    var processed = 0;

    await for (final line in lines) {
      if (line.trim() == '</>') {
        final parsed = _parseDelimitedBlock(blockLines);
        final record = parsed?.record;
        if (record != null) {
          yield record;
        }
        blockLines.clear();
        processed++;
        if (processed % _importYieldEvery == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      } else {
        blockLines.add(line);
      }
    }

    final parsed = _parseDelimitedBlock(blockLines);
    final record = parsed?.record;
    if (record != null) {
      yield record;
    }
  }

  static _LineRecordParseResult? _parseDelimitedBlock(List<String> blockLines) {
    final lines = blockLines
        .map((line) => line.trimRight())
        .where((line) => line.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) {
      return null;
    }

    return _tryParseLineRecord(
      () => _recordFromParts(lines.first, lines.skip(1).join('\n')),
    );
  }

  Future<DictionaryImportResult> _importLineRecords(
    Stream<String> lines, {
    required String name,
    required _LineRecordParseResult? Function(String line) parser,
  }) async {
    final directory = await _resolveDictionaryDirectory();
    final entriesFile = File('${directory.path}/$_entriesFileName');
    final indexFile = File('${directory.path}/$_indexFileName');
    final manifestFile = File('${directory.path}/$_manifestFileName');
    final nextIndex = <String, int>{};
    final sink = entriesFile.openWrite(mode: FileMode.write);
    var dictionaryName = name;
    var written = 0;
    var skipped = 0;
    var processed = 0;
    var byteOffset = 0;

    try {
      await for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) {
          continue;
        }

        try {
          final parsed = parser(trimmed);
          if (parsed == null) {
            skipped++;
            continue;
          }
          if (parsed.manifestName != null) {
            dictionaryName = parsed.manifestName ?? dictionaryName;
            continue;
          }

          final record = parsed.record;
          if (record == null) {
            skipped++;
            continue;
          }
          final keys = _indexKeysFor(record)
              .where((key) => !nextIndex.containsKey(key))
              .toList();
          if (keys.isEmpty) {
            skipped++;
            continue;
          }

          final offset = byteOffset;
          final lineData = '${jsonEncode(record.toJson())}\n';
          sink.write(lineData);
          byteOffset += utf8.encode(lineData).length;
          for (final key in keys) {
            nextIndex[key] = offset;
          }
          written++;
          processed++;
          if (processed % _importYieldEvery == 0) {
            await sink.flush();
            await Future<void>.delayed(Duration.zero);
          }
        } catch (_) {
          skipped++;
        }
      }
    } finally {
      await sink.close();
    }

    return _saveImportedDictionary(
      name: dictionaryName,
      entryCount: written,
      skippedCount: skipped,
      nextIndex: nextIndex,
      indexFile: indexFile,
      manifestFile: manifestFile,
    );
  }

  Future<DictionaryImportResult> _importJsonValue(
    dynamic decoded, {
    required String name,
  }) {
    String dictionaryName = name;
    final records = <_DictionaryRecord>[];
    var skipped = 0;

    if (decoded is List<dynamic>) {
      for (final item in decoded) {
        final record = _tryParseRecord(() => _recordFromJsonItem(item));
        if (record == null) {
          skipped++;
          continue;
        }
        records.add(record);
      }
    } else if (decoded is Map<String, dynamic>) {
      dictionaryName = decoded['name'] as String? ?? dictionaryName;
      final entries = decoded['entries'] ??
          decoded['words'] ??
          decoded['items'] ??
          decoded['data'] ??
          decoded['records'] ??
          decoded['list'];
      if (entries is List<dynamic>) {
        for (final item in entries) {
          final record = _tryParseRecord(() => _recordFromJsonItem(item));
          if (record == null) {
            skipped++;
            continue;
          }
          records.add(record);
        }
      } else {
        for (final item in decoded.entries) {
          if (item.value is String || item.value is Map<String, dynamic>) {
            final record = _tryParseRecord(
              () => _recordFromMapEntry(item.key, item.value),
            );
            if (record != null) {
              records.add(record);
            }
          }
        }
      }
    } else {
      throw const DictionaryFormatException('JSON 词典格式不支持');
    }

    return _writeDictionaryRecords(
      records,
      name: dictionaryName,
      skippedCount: skipped,
    );
  }

  Future<DictionaryImportResult> _writeDictionaryRecords(
    List<_DictionaryRecord> records, {
    required String name,
    required int skippedCount,
  }) async {
    return _writeRecordStream(
      Stream<_DictionaryRecord>.fromIterable(records),
      name: name,
      skippedCount: skippedCount,
    );
  }

  Future<DictionaryImportResult> _writeRecordStream(
    Stream<_DictionaryRecord> records, {
    required String name,
    required int skippedCount,
  }) async {
    final directory = await _resolveDictionaryDirectory();
    final entriesFile = File('${directory.path}/$_entriesFileName');
    final indexFile = File('${directory.path}/$_indexFileName');
    final manifestFile = File('${directory.path}/$_manifestFileName');
    final nextIndex = <String, int>{};

    final sink = entriesFile.openWrite(mode: FileMode.write);
    var written = 0;
    var byteOffset = 0;
    try {
      await for (final record in records) {
        final keys = _indexKeysFor(record)
            .where((key) => !nextIndex.containsKey(key))
            .toList();
        if (keys.isEmpty) {
          skippedCount++;
          continue;
        }

        final offset = byteOffset;
        final lineData = '${jsonEncode(record.toJson())}\n';
        sink.write(lineData);
        byteOffset += utf8.encode(lineData).length;
        for (final key in keys) {
          nextIndex[key] = offset;
        }
        written++;
        if (written % _importYieldEvery == 0) {
          await sink.flush();
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      await sink.close();
    }

    return _saveImportedDictionary(
      name: name,
      entryCount: written,
      skippedCount: skippedCount,
      nextIndex: nextIndex,
      indexFile: indexFile,
      manifestFile: manifestFile,
    );
  }

  Future<DictionaryImportResult> _saveImportedDictionary({
    required String name,
    required int entryCount,
    required int skippedCount,
    required Map<String, int> nextIndex,
    required File indexFile,
    required File manifestFile,
  }) async {
    await _writeIndexFile(indexFile, nextIndex);
    await manifestFile.writeAsString(
      jsonEncode({
        'format': 'ytpodcast-dict-v1',
        'name': name,
        'entryCount': entryCount,
        'updatedAt': DateTime.now().toIso8601String(),
      }),
    );

    _index
      ..clear()
      ..addAll(nextIndex);
    _lookupCache.clear();
    _dictionaryName = name;
    _dictionaryEntryCount = entryCount;

    return DictionaryImportResult(
      name: name,
      entryCount: entryCount,
      skippedCount: skippedCount,
    );
  }

  Future<void> _loadIndexFile(File indexFile) async {
    var loaded = 0;
    await for (final line in indexFile
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      if (trimmed.startsWith('{')) {
        final json = jsonDecode(trimmed) as Map<String, dynamic>;
        for (final item in json.entries) {
          final offset = item.value;
          if (offset is num) {
            _index[item.key] = offset.toInt();
          }
        }
        return;
      }

      final tabIndex = trimmed.lastIndexOf('\t');
      if (tabIndex <= 0) {
        continue;
      }
      final offset = int.tryParse(trimmed.substring(tabIndex + 1));
      if (offset == null) {
        continue;
      }
      _index[trimmed.substring(0, tabIndex)] = offset;
      loaded++;
      if (loaded % _importYieldEvery == 0) {
        await Future<void>.delayed(Duration.zero);
      }
    }
  }

  Future<void> _writeIndexFile(File indexFile, Map<String, int> index) async {
    final sink = indexFile.openWrite(mode: FileMode.write);
    var written = 0;
    try {
      for (final item in index.entries) {
        sink.writeln('${item.key}\t${item.value}');
        written++;
        if (written % _importYieldEvery == 0) {
          await sink.flush();
          await Future<void>.delayed(Duration.zero);
        }
      }
    } finally {
      await sink.close();
    }
  }

  Future<Directory> _resolveDictionaryDirectory() async {
    final existing = _dictionaryDirectory;
    if (existing != null) {
      return existing;
    }

    final root = await _resolveDocumentsPath();
    final directory = Directory('$root/dictionary');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _dictionaryDirectory = directory;
    return directory;
  }

  DictionaryEntry _fallbackEntry(String word) {
    final normalized = normalizeWord(word);
    final meaning = _meanings[normalized] ?? '暂未收录，后续可导入本地词典';

    return DictionaryEntry(
      word: normalized,
      meaning: meaning,
      fullMeaning: _meanings.containsKey(normalized)
          ? '$normalized：$meaning。MVP 释义：结合字幕原句记忆，并在复习时反复听原音。'
          : '$normalized：本地词典未收录。后续可以导入由 MDX 转换出的 JSONL/.dict 词典。',
    );
  }

  void _cacheLookup(String key, DictionaryEntry entry) {
    if (_lookupCache.length > 160) {
      _lookupCache.clear();
    }
    _lookupCache[key] = entry;
  }

  static String normalizeWord(String word) {
    final normalized = word
        .toLowerCase()
        .trim();
    final match = RegExp(r"[a-z0-9]+(?:[-'][a-z0-9]+)*").firstMatch(
      normalized,
    );
    return match?.group(0) ?? '';
  }

  static String meaningForDisplay(String value) {
    return _cleanDictionaryText(value);
  }

  static String htmlForDisplay(String value, {String? headword}) {
    return _formatDictionaryHtml(value, headword: headword);
  }

  static bool _isManifestLine(Map<String, dynamic> json) {
    return json['format'] == 'ytpodcast-dict-v1' ||
        json['type'] == 'manifest';
  }

  static Future<String> _resolveDocumentsPath() async {
    try {
      final path = await _directoryChannel.invokeMethod<String>(
        'documentsPath',
      );
      if (path != null && path.isNotEmpty) {
        return path;
      }
    } catch (_) {}

    return '${Directory.systemTemp.path}/ytpodcast';
  }

  static String _extensionOf(String path) {
    final name = _basename(path).toLowerCase();
    final index = name.lastIndexOf('.');
    return index >= 0 ? name.substring(index) : '';
  }

  static String _basenameWithoutExtension(String path) {
    final name = _basename(path);
    final index = name.lastIndexOf('.');
    return index >= 0 ? name.substring(0, index) : name;
  }

  static String _basename(String path) {
    return path.split(RegExp(r'[\\/]')).last;
  }

  static bool _isTextDictionaryExtension(String extension) {
    return {
      '.txt',
      '.tab',
      '.tsv',
      '.csv',
    }.contains(extension);
  }

  static bool _looksLikeDelimitedDictionary(String raw) {
    return RegExp(r'(^|\r?\n)\s*</>\s*(\r?\n|$)').hasMatch(raw);
  }

  static Iterable<String> _splitDelimitedEntries(String raw) sync* {
    final buffer = StringBuffer();
    for (final line in const LineSplitter().convert(raw)) {
      if (line.trim() == '</>') {
        final block = buffer.toString().trim();
        if (block.isNotEmpty) {
          yield block;
        }
        buffer.clear();
      } else {
        buffer.writeln(line);
      }
    }

    final tail = buffer.toString().trim();
    if (tail.isNotEmpty) {
      yield tail;
    }
  }

  static _LineRecordParseResult? _parseJsonLine(String line) {
    final json = jsonDecode(line) as Map<String, dynamic>;
    if (_isManifestLine(json)) {
      return _LineRecordParseResult.manifest(json['name'] as String?);
    }
    return _LineRecordParseResult.record(_DictionaryRecord.fromJson(json));
  }

  static _LineRecordParseResult? _parseFlexibleTextLine(String line) {
    final cleanLine = line.replaceFirst('\uFEFF', '').trim();
    if (cleanLine.isEmpty || cleanLine.startsWith('#')) {
      return null;
    }

    if (cleanLine.startsWith('{')) {
      return _parseJsonLine(cleanLine);
    }

    final tabParts = cleanLine.split('\t');
    if (tabParts.length >= 2) {
      return _recordFromParts(tabParts.first, tabParts.sublist(1).join('\n'));
    }

    final commaIndex = cleanLine.indexOf(',');
    if (commaIndex > 0) {
      return _recordFromParts(
        cleanLine.substring(0, commaIndex),
        cleanLine.substring(commaIndex + 1),
      );
    }

    return null;
  }

  static _LineRecordParseResult? _recordFromParts(String word, String meaning) {
    final words = _expandHeadwords([word]);
    final cleanWord = words.isEmpty ? '' : words.first;
    final rawMeaning = meaning.trim();
    if (cleanWord.isEmpty || rawMeaning.isEmpty) {
      return null;
    }

    return _LineRecordParseResult.record(
      _DictionaryRecord(
        word: cleanWord,
        aliases: words.skip(1).toList(),
        meaning: rawMeaning,
        fullMeaning: rawMeaning,
        html: rawMeaning,
      ),
    );
  }

  static _DictionaryRecord? _recordFromJsonItem(dynamic item) {
    if (item is Map<String, dynamic>) {
      return _DictionaryRecord.fromJson(item);
    }
    if (item is List<dynamic> && item.length >= 2) {
      final words = _expandHeadwords(_stringsFromValue(item.first));
      if (words.isEmpty) {
        return null;
      }
      final meaning = item[1].toString().trim();
      final fullMeaning = item.length >= 3
          ? item[2].toString().trim()
          : meaning;
      return _DictionaryRecord(
        word: words.first,
        aliases: words.skip(1).toList(),
        meaning: fullMeaning,
        fullMeaning: fullMeaning,
        html: fullMeaning,
      );
    }
    return null;
  }

  static _DictionaryRecord? _recordFromMapEntry(String key, dynamic value) {
    if (value is String) {
      final rawMeaning = value.trim();
      return _DictionaryRecord(
        word: key,
        meaning: rawMeaning,
        fullMeaning: rawMeaning,
        html: rawMeaning,
      );
    }
    if (value is Map<String, dynamic>) {
      return _DictionaryRecord.fromJson({
        ...value,
        'word': key,
      });
    }
    return null;
  }

  static _DictionaryRecord? _tryParseRecord(
    _DictionaryRecord? Function() parse,
  ) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }

  static _LineRecordParseResult? _tryParseLineRecord(
    _LineRecordParseResult? Function() parse,
  ) {
    try {
      return parse();
    } catch (_) {
      return null;
    }
  }

  static List<String> _stringsFromValue(dynamic value) {
    if (value == null) {
      return const [];
    }
    if (value is String) {
      final trimmed = value.trim();
      return trimmed.isEmpty ? const [] : [trimmed];
    }
    if (value is Iterable) {
      final strings = <String>[];
      for (final item in value) {
        strings.addAll(_stringsFromValue(item));
      }
      return strings;
    }
    return const [];
  }

  static List<String> _expandHeadwords(Iterable<String> values) {
    final seen = <String>{};
    final words = <String>[];

    for (final value in values) {
      for (final alias in _headwordAliases(value)) {
        final trimmed = alias.trim();
        final normalized = normalizeWord(trimmed);
        if (trimmed.isNotEmpty && normalized.isNotEmpty && seen.add(normalized)) {
          words.add(trimmed);
        }
      }
    }

    return words;
  }

  static Iterable<String> _lookupCandidates(String word) sync* {
    final seen = <String>{};

    void add(String candidate) {
      final normalized = normalizeWord(candidate);
      if (normalized.isNotEmpty && seen.add(normalized)) {
        // Empty body; yielded below by reading seen.
      }
    }

    if (word.endsWith("'s")) {
      add(word.substring(0, word.length - 2));
    }
    if (word.endsWith("s'")) {
      add(word.substring(0, word.length - 2));
    }
    if (word.endsWith('ies') && word.length > 4) {
      add('${word.substring(0, word.length - 3)}y');
    }
    if (word.endsWith('ves') && word.length > 4) {
      add('${word.substring(0, word.length - 3)}f');
      add('${word.substring(0, word.length - 3)}fe');
    }
    if (word.endsWith('es') && word.length > 3) {
      add(word.substring(0, word.length - 2));
    }
    if (word.endsWith('s') && word.length > 3) {
      add(word.substring(0, word.length - 1));
    }
    if (word.endsWith('ied') && word.length > 4) {
      add('${word.substring(0, word.length - 3)}y');
    }
    if (word.endsWith('ed') && word.length > 4) {
      final base = word.substring(0, word.length - 2);
      add(base);
      add('${base}e');
      if (base.length > 2 && base[base.length - 1] == base[base.length - 2]) {
        add(base.substring(0, base.length - 1));
      }
    }
    if (word.endsWith('ing') && word.length > 5) {
      final base = word.substring(0, word.length - 3);
      add(base);
      add('${base}e');
      if (base.length > 2 && base[base.length - 1] == base[base.length - 2]) {
        add(base.substring(0, base.length - 1));
      }
    }

    const irregular = {
      'understood': 'understand',
      'spoken': 'speak',
      'spoke': 'speak',
      'written': 'write',
      'wrote': 'write',
      'gone': 'go',
      'went': 'go',
      'seen': 'see',
      'saw': 'see',
      'known': 'know',
      'knew': 'know',
      'made': 'make',
      'taken': 'take',
      'took': 'take',
      'given': 'give',
      'gave': 'give',
      'found': 'find',
      'thought': 'think',
      'brought': 'bring',
      'bought': 'buy',
      'heard': 'hear',
      'felt': 'feel',
      'left': 'leave',
      'kept': 'keep',
      'met': 'meet',
      'paid': 'pay',
      'said': 'say',
      'told': 'tell',
      'won': 'win',
      'better': 'good',
      'best': 'good',
      'worse': 'bad',
      'worst': 'bad',
    };
    final irregularBase = irregular[word];
    if (irregularBase != null) {
      add(irregularBase);
    }

    add(word);

    for (final candidate in seen) {
      yield candidate;
    }
  }

  static Set<String> _indexKeysFor(_DictionaryRecord record) {
    final keys = <String>{};

    void add(String? value) {
      if (value == null || value.trim().isEmpty) {
        return;
      }
      for (final alias in _headwordAliases(value)) {
        final normalized = normalizeWord(alias);
        if (normalized.isNotEmpty) {
          keys.add(normalized);
        }
      }
    }

    add(record.word);
    add(record.headword);
    for (final alias in record.aliases) {
      add(alias);
    }

    final displayHeadword = _extractDisplayHeadword(record.html);
    add(displayHeadword);

    return keys;
  }

  static Iterable<String> _headwordAliases(String value) sync* {
    final clean = _cleanDictionaryText(value)
        .replaceAll(RegExp(r'\[[^\]]+\]'), ' ')
        .replaceAll(RegExp(r'\([^)]*\)'), ' ')
        .trim();
    if (clean.isEmpty) {
      return;
    }

    yield clean;
    for (final part in clean.split(RegExp(r'[|;,，；、/]+'))) {
      final trimmed = part.trim();
      if (trimmed.isNotEmpty) {
        yield trimmed;
      }
    }

    final firstWord = RegExp(r"[A-Za-z][A-Za-z0-9\-']*").firstMatch(clean);
    if (firstWord != null) {
      yield firstWord.group(0)!;
    }
  }

  static String? _extractDisplayHeadword(String? html) {
    if (html == null || html.trim().isEmpty) {
      return null;
    }
    final match = RegExp(
      r'<(?:hwd|hw|c)\b[^>]*>(.*?)</(?:hwd|hw|c)>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    if (match == null) {
      return null;
    }
    return match.group(1);
  }

  static String _cleanDictionaryText(String value) {
    final withoutTags = value
        .replaceAll(RegExp(r'<link\b[^>]*>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>',
            caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>',
            caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</(def|sc|sb|ex|exp|eg|eps|uit|x|en|zh)>',
            caseSensitive: false), '\n')
        .replaceAll(RegExp(r'<(hwd|hw|c|pho|pos|prx|sqn|sqa|cn|rw|sa|def|sc|sb|ex|exp|eg|eps|uit|x|en|zh)\b[^>]*>',
            caseSensitive: false), ' ')
        .replaceAll(RegExp(r'</(hwd|hw|c|pho|pos|prx|sqn|sqa|cn|rw|sa)\b[^>]*>',
            caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'&nbsp;'), ' ')
        .replaceAll(RegExp(r'&amp;'), '&')
        .replaceAll(RegExp(r'&lt;'), '<')
        .replaceAll(RegExp(r'&gt;'), '>')
        .replaceAll(RegExp(r'&quot;'), '"')
        .replaceAll(RegExp(r'&#39;'), "'");
    final text = withoutTags
        .replaceAll(RegExp(r'<link\b[^>]*>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>',
            caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>',
            caseSensitive: false, dotAll: true), ' ')
        .replaceAll(RegExp(r'<[^>]+>'), ' ')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n\s*\n+'), '\n')
        .trim();
    return text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .where((line) => !_looksLikeNoise(line))
        .join('\n')
        .trim();
  }

  static bool _looksLikeNoise(String line) {
    final lower = line.toLowerCase();
    return lower.endsWith('.css') ||
        lower.contains('stylesheet') ||
        lower.contains('javascript') ||
        lower.contains('function(');
  }

  static String _formatDictionaryHtml(String raw, {String? headword}) {
    var body = raw.trim();
    if (body.contains('&lt;') && body.contains('&gt;')) {
      body = body
          .replaceAll(RegExp(r'&lt;', caseSensitive: false), '<')
          .replaceAll(RegExp(r'&gt;', caseSensitive: false), '>')
          .replaceAll(RegExp(r'&quot;', caseSensitive: false), '"')
          .replaceAll(RegExp(r'&#39;', caseSensitive: false), "'")
          .replaceAll(RegExp(r'&amp;', caseSensitive: false), '&');
    }

    body = body
        .replaceAll(RegExp(r'<link\b[^>]*>', caseSensitive: false), '')
        .replaceAll(RegExp(r'<style\b[^>]*>.*?</style>',
            caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script\b[^>]*>.*?</script>',
            caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<rw\b[^>]*>', caseSensitive: false), '<div>')
        .replaceAll(RegExp(r'</rw>', caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<hwd\b[^>]*>', caseSensitive: false),
            '<div class="headword">')
        .replaceAll(RegExp(r'</hwd>', caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<hw\b[^>]*>', caseSensitive: false),
            '<span class="headword">')
        .replaceAll(RegExp(r'</hw>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<c\b[^>]*>', caseSensitive: false),
            '<span class="headword-text">')
        .replaceAll(RegExp(r'</c>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<pho\b[^>]*>', caseSensitive: false),
            '<span class="phonetic">')
        .replaceAll(RegExp(r'</pho>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<pos\b[^>]*>', caseSensitive: false),
            '<span class="pos">')
        .replaceAll(RegExp(r'</pos>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<prx\b[^>]*>', caseSensitive: false),
            '<span class="label">')
        .replaceAll(RegExp(r'</prx>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<cn\b[^>]*>', caseSensitive: false),
            '<span class="label">')
        .replaceAll(RegExp(r'</cn>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<sqn\b[^>]*>', caseSensitive: false),
            '<span class="sense-number">')
        .replaceAll(RegExp(r'</sqn>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<sqa\b[^>]*>', caseSensitive: false),
            '<span class="sense-letter">')
        .replaceAll(RegExp(r'</sqa>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<def\b[^>]*>', caseSensitive: false),
            '<div class="definition">')
        .replaceAll(RegExp(r'</def>', caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<uit\b[^>]*>', caseSensitive: false),
            '<div class="unit">')
        .replaceAll(RegExp(r'</uit>', caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<en\b[^>]*>', caseSensitive: false),
            '<span class="en">')
        .replaceAll(RegExp(r'</en>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<zh\b[^>]*>', caseSensitive: false),
            '<span class="zh">')
        .replaceAll(RegExp(r'</zh>', caseSensitive: false), '</span>')
        .replaceAll(RegExp(r'<ex\b[^>]*>|<exp\b[^>]*>|<eg\b[^>]*>|<eps\b[^>]*>',
            caseSensitive: false), '<div class="example">')
        .replaceAll(RegExp(r'</ex>|</exp>|</eg>|</eps>',
            caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<sc\b[^>]*>|<sb\b[^>]*>',
            caseSensitive: false), '<div class="sense">')
        .replaceAll(RegExp(r'</sc>|</sb>', caseSensitive: false), '</div>')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '<br>');

    body = _stripInflectionHeader(body, headword);

    if (!body.contains('<')) {
      body = _escapeHtml(body).replaceAll('\n', '<br>');
    }

    final title = headword == null || headword.trim().isEmpty
        ? ''
        : '<div class="entry-title">${_escapeHtml(headword.trim())}</div>';

    return '$title$body';
  }

  static String _stripInflectionHeader(String html, String? headword) {
    var body = html
        .replaceAll(
          RegExp(
            r'<div class="entry-title">.*?</div>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<div class="headword">.*?</div>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<span class="headword">.*?</span>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .replaceAll(
          RegExp(
            r'<span class="headword-text">.*?</span>',
            caseSensitive: false,
            dotAll: true,
          ),
          '',
        )
        .trimLeft();

    final normalizedHeadword = normalizeWord(headword ?? '');
    if (normalizedHeadword.isEmpty) {
      return body;
    }

    body = _stripLeadingInflectionBlocks(body, normalizedHeadword);

    final marker = _firstDefinitionMarker(body);
    if (marker <= 0) {
      return body;
    }

    final prefix = body.substring(0, marker);
    final tokens = RegExp(r"[A-Za-z][A-Za-z0-9\-']*")
        .allMatches(_cleanDictionaryText(prefix))
        .map((match) => normalizeWord(match.group(0)!))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return body;
    }

    final forms = _inflectionForms(normalizedHeadword);
    final onlyInflections = tokens.every(forms.contains);
    return onlyInflections ? body.substring(marker).trimLeft() : body;
  }

  static String _stripLeadingInflectionBlocks(String html, String headword) {
    var body = html.trimLeft();
    final forms = _inflectionForms(headword);
    final alternation = forms.map(RegExp.escape).join('|');
    final tag = r'<[^>]+>';
    final separator = r'(?:\s|&nbsp;|<br>|<br/>|<br />|' +
        tag +
        r'|[|｜,;])+';
    final blockPattern = RegExp(
      r'^(?:\s|' +
          tag +
          r')*'
      r'((?:' +
          alternation +
          r')(?:' +
          separator +
          r'(?:' +
          alternation +
          r'))+(?:' +
          separator +
          r')*)',
      caseSensitive: false,
    );

    while (true) {
      final match = blockPattern.firstMatch(body);
      if (match == null) {
        return _stripLeadingInflectionText(body, headword, forms);
      }

      final block = match.group(1) ?? '';
      final tokens = RegExp(r"[A-Za-z][A-Za-z0-9\-']*")
          .allMatches(_cleanDictionaryText(block))
          .map((item) => normalizeWord(item.group(0)!))
          .where((token) => token.isNotEmpty)
          .toList();
      final hasInflectedForm =
          tokens.any((token) => token != headword && forms.contains(token));
      if (!hasInflectedForm) {
        return _stripLeadingInflectionText(body, headword, forms);
      }

      body = body.substring(match.end).trimLeft();
    }
  }

  static String _stripLeadingInflectionText(
    String html,
    String headword,
    Set<String> forms,
  ) {
    final clean = _cleanDictionaryText(html);
    final normalized = clean
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .replaceAll(RegExp(r'\n+'), ' ')
        .trimLeft();
    if (normalized.isEmpty) {
      return html.trimLeft();
    }

    final tokens = RegExp(r"[A-Za-z][A-Za-z0-9\-']*")
        .allMatches(normalized)
        .map((match) => normalizeWord(match.group(0)!))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.length < 2 ||
        !tokens.any((token) => token != headword && forms.contains(token))) {
      return html.trimLeft();
    }

    var consumedTokenCount = 0;
    var sawInflectedForm = false;
    for (final token in tokens) {
      if (!forms.contains(token)) {
        break;
      }
      if (token == headword && consumedTokenCount > 0 && sawInflectedForm) {
        break;
      }
      if (token != headword) {
        sawInflectedForm = true;
      }
      consumedTokenCount++;
    }
    if (consumedTokenCount < 2) {
      return html.trimLeft();
    }

    final leadingTokens = tokens.take(consumedTokenCount).toList();
    final boundary = r'(?:\s|&nbsp;|<[^>]+>|[|｜,;])+';
    final leadingPattern = leadingTokens
        .map(RegExp.escape)
        .join(boundary);
    final pattern = RegExp(
      r'^(?:\s|&nbsp;|<[^>]+>|[|｜,;])*'
      r'(?:' +
          leadingPattern +
          r')'
          r'(?:\s|&nbsp;|<[^>]+>|[|｜,;])*',
      caseSensitive: false,
    );
    final match = pattern.firstMatch(html.trimLeft());
    if (match == null) {
      return html.trimLeft();
    }
    return html.trimLeft().substring(match.end).trimLeft();
  }

  static int _firstDefinitionMarker(String html) {
    const markers = [
      '<span class="phonetic"',
      '<span class="pos"',
      '<div class="definition"',
      '<div class="sense"',
      '<div class="unit"',
      '<span class="sense-number"',
    ];
    final lower = html.toLowerCase();
    var result = -1;
    for (final marker in markers) {
      final index = lower.indexOf(marker);
      if (index >= 0 && (result < 0 || index < result)) {
        result = index;
      }
    }
    return result;
  }

  static Set<String> _inflectionForms(String word) {
    final forms = <String>{word};
    if (word.isEmpty) {
      return forms;
    }

    forms.add('${word}s');
    forms.add('${word}es');
    if (word.endsWith('e')) {
      forms.add('${word}d');
      forms.add('${word.substring(0, word.length - 1)}ing');
    } else {
      forms.add('${word}ed');
      forms.add('${word}ing');
    }
    if (word.endsWith('y') && word.length > 1) {
      forms.add('${word.substring(0, word.length - 1)}ies');
      forms.add('${word.substring(0, word.length - 1)}ied');
    }
    if (word.length > 2) {
      final last = word[word.length - 1];
      forms.add('$word$last');
      forms.add('$word${last}ed');
      forms.add('$word${last}ing');
    }

    return forms;
  }

  static String _escapeHtml(String value) {
    return value
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

class _LineRecordParseResult {
  const _LineRecordParseResult._({this.record, this.manifestName});

  factory _LineRecordParseResult.record(_DictionaryRecord record) {
    return _LineRecordParseResult._(record: record);
  }

  factory _LineRecordParseResult.manifest(String? name) {
    return _LineRecordParseResult._(manifestName: name);
  }

  final _DictionaryRecord? record;
  final String? manifestName;
}

class _DictionaryRecord {
  const _DictionaryRecord({
    required this.word,
    required this.meaning,
    required this.fullMeaning,
    this.aliases = const [],
    this.headword,
    this.phonetic,
    this.html,
  });

  final String word;
  final List<String> aliases;
  final String? headword;
  final String meaning;
  final String fullMeaning;
  final String? phonetic;
  final String? html;

  factory _DictionaryRecord.fromJson(Map<String, dynamic> json) {
    final words = DictionaryService._expandHeadwords(
      _readStrings(json, [
        'word',
        'words',
        'headword',
        'headwords',
        'title',
        'term',
        'key',
        'phrase',
        'entry',
        'k',
        'w',
        'l',
      ]),
    );
    final html = _readString(json, [
      'html',
      'definitionHtml',
      'article',
      'content',
      'body',
      'raw',
      'defi',
      'd',
    ]);
    final plain = _readString(json, [
      'plain',
      'meaning',
      'definition',
      'def',
      'text',
      'value',
      'v',
      'defi',
      'd',
      'description',
      'translation',
    ]);
    final full = _readString(json, [
      'fullMeaning',
      'full',
      'definition',
      'def',
      'article',
      'content',
      'body',
      'raw',
      'defi',
      'd',
      'description',
      'translation',
    ]);
    final word = words.isEmpty ? null : words.first;
    final headwords = DictionaryService._expandHeadwords(
      _readStrings(json, ['headword', 'title']),
    );

    if (word == null || word.trim().isEmpty) {
      throw const DictionaryFormatException('词条缺少 word');
    }
    final displayWord = word.trim();
    if ((plain == null || plain.trim().isEmpty) &&
        (full == null || full.trim().isEmpty) &&
        (html == null || html.trim().isEmpty)) {
      throw const DictionaryFormatException('词条缺少 plain/meaning/html');
    }

    final fullText = DictionaryService._cleanDictionaryText(
      full ?? plain ?? html!,
    );
    final displayHtml = DictionaryService._formatDictionaryHtml(
      html ?? full ?? plain!,
      headword: displayWord,
    );

    return _DictionaryRecord(
      word: displayWord,
      aliases: [
        ...words.skip(1),
        ...headwords.skip(1),
        ..._readStrings(json, ['alias', 'aliases', 'alternate', 'alternates']),
      ],
      headword: displayWord,
      phonetic: _readString(json, ['phonetic', 'pronunciation', 'phone', 'phon']),
      meaning: fullText,
      fullMeaning: fullText,
      html: displayHtml,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'word': word,
      if (aliases.isNotEmpty) 'aliases': aliases,
      if (headword != null) 'headword': headword,
      if (phonetic != null) 'phonetic': phonetic,
      'meaning': meaning,
      'fullMeaning': fullMeaning,
      if (html != null) 'html': html,
    };
  }

  DictionaryEntry toEntry({String? source}) {
    final canonicalWord = DictionaryService.normalizeWord(word);
    return DictionaryEntry(
      word: canonicalWord,
      headword: canonicalWord,
      phonetic: phonetic,
      meaning: meaning,
      fullMeaning: fullMeaning,
      html: html,
      source: source,
      isLocal: true,
    );
  }

  static String? _readString(Map<String, dynamic> json, List<String> keys) {
    final values = _readStrings(json, keys);
    return values.isEmpty ? null : values.first;
  }

  static List<String> _readStrings(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      final strings = DictionaryService._stringsFromValue(value);
      if (strings.isNotEmpty) {
        return strings;
      }
    }
    return const [];
  }
}

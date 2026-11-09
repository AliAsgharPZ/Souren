import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:zstandard/zstandard.dart';

import 'store.dart';

/// On-demand reader for the independently-compressed Ganjoor content pack.
///
/// The pack remains compressed in filesDir. A request reads only the indexed
/// Zstandard frame that contains the requested JSON file; one decoded frame
/// is retained in memory and replaced when another frame is needed.
class GanjoorPack {
  static const _releaseBase =
      'https://github.com/AliAsgharPZ/Souren/releases/download/ganjoor-pack-latest';
  static const _indexName = 'souren-ganjoor-index.json';
  static const _packName = 'souren-ganjoor-pack.bin';
  static const _indexUrl = '$_releaseBase/$_indexName';
  static const _packUrl = '$_releaseBase/$_packName';

  static final Zstandard _zstandard = Zstandard();
  static Map<String, dynamic>? _index;
  static int? _cachedChunkId;
  static Uint8List? _cachedChunk;

  static Future<Map<String, dynamic>?> _loadIndex() async {
    if (_index != null) return _index;
    final index = await SharedFiles.readJson(_indexName);
    if (index == null || index['format'] != 1) return null;
    _index = index;
    return index;
  }

  static Future<bool> isInstalled() async {
    try {
      final index = await _loadIndex();
      if (index == null) return false;
      final pack = await SharedFiles.file(_packName);
      if (!await pack.exists()) return false;
      return await pack.length() == (index['pack_bytes'] as num).toInt();
    } catch (_) {
      return false;
    }
  }

  static Future<int> storedBytes() async {
    final index = await _loadIndex();
    if (index == null) return 0;
    final indexFile = await SharedFiles.file(_indexName);
    final packFile = await SharedFiles.file(_packName);
    final indexBytes = await indexFile.exists() ? await indexFile.length() : 0;
    final packBytes = await packFile.exists() ? await packFile.length() : 0;
    return indexBytes + packBytes;
  }

  /// Downloads to temporary files and swaps them into place only after the
  /// complete pack has arrived. [onProgress] reports bytes received and total.
  static Future<void> download({
    void Function(int received, int total)? onProgress,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 20);
    try {
      final indexRequest = await client.getUrl(Uri.parse(_indexUrl));
      final indexResponse = await indexRequest.close().timeout(
        const Duration(seconds: 45),
      );
      if (indexResponse.statusCode != HttpStatus.ok) {
        throw HttpException('Index download failed: HTTP ${indexResponse.statusCode}');
      }
      final indexBytes = await indexResponse.fold<List<int>>(
        <int>[],
        (buffer, part) => buffer..addAll(part),
      );
      final index = jsonDecode(utf8.decode(indexBytes)) as Map<String, dynamic>;
      if (index['format'] != 1 || index['pack_bytes'] is! num) {
        throw const FormatException('Unsupported Ganjoor pack index');
      }
      final expectedBytes = (index['pack_bytes'] as num).toInt();

      final packFile = await SharedFiles.file(_packName);
      final indexFile = await SharedFiles.file(_indexName);
      final packTemp = File('${packFile.path}.download');
      final indexTemp = File('${indexFile.path}.download');
      if (await packTemp.exists()) await packTemp.delete();
      if (await indexTemp.exists()) await indexTemp.delete();

      final packRequest = await client.getUrl(Uri.parse(_packUrl));
      final packResponse = await packRequest.close().timeout(
        const Duration(seconds: 60),
      );
      if (packResponse.statusCode != HttpStatus.ok) {
        throw HttpException('Pack download failed: HTTP ${packResponse.statusCode}');
      }
      final total = packResponse.contentLength > 0
          ? packResponse.contentLength
          : expectedBytes;
      var received = 0;
      final sink = packTemp.openWrite();
      try {
        await for (final part in packResponse) {
          sink.add(part);
          received += part.length;
          onProgress?.call(received, total);
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (received != expectedBytes || await packTemp.length() != expectedBytes) {
        throw const FormatException('Downloaded Ganjoor pack size mismatch');
      }

      await indexTemp.writeAsBytes(indexBytes, flush: true);
      if (await packFile.exists()) await packFile.delete();
      await packTemp.rename(packFile.path);
      if (await indexFile.exists()) await indexFile.delete();
      await indexTemp.rename(indexFile.path);
      _index = index;
      _cachedChunkId = null;
      _cachedChunk = null;
    } catch (_) {
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> remove() async {
    for (final name in [_indexName, _packName]) {
      final file = await SharedFiles.file(name);
      if (await file.exists()) await file.delete();
    }
    _index = null;
    _cachedChunkId = null;
    _cachedChunk = null;
  }

  static Future<Uint8List> _readChunk(
    Map<String, dynamic> index,
    int chunkId,
  ) async {
    if (_cachedChunkId == chunkId && _cachedChunk != null) {
      return _cachedChunk!;
    }
    final chunks = index['chunks'] as List;
    if (chunkId < 0 || chunkId >= chunks.length) {
      throw const FormatException('Invalid Ganjoor chunk reference');
    }
    final chunk = Map<String, dynamic>.from(chunks[chunkId] as Map);
    final pack = await SharedFiles.file(_packName);
    final file = await pack.open();
    late final Uint8List compressed;
    try {
      await file.setPosition(
        (chunk['compressed_offset'] as num).toInt(),
      );
      final bytes = await file.read(
        (chunk['compressed_length'] as num).toInt(),
      );
      if (bytes.length != (chunk['compressed_length'] as num).toInt()) {
        throw const FormatException('Incomplete Ganjoor frame in pack');
      }
      compressed = Uint8List.fromList(bytes);
    } finally {
      await file.close();
    }
    final decoded = await _zstandard.decompress(compressed);
    if (decoded == null ||
        decoded.length != (chunk['raw_length'] as num).toInt()) {
      throw const FormatException('Ganjoor frame decompression failed');
    }
    _cachedChunkId = chunkId;
    _cachedChunk = decoded;
    return decoded;
  }

  /// Returns a decoded source JSON file, or null when the pack has no entry.
  static Future<Map<String, dynamic>?> readJson(String path) async {
    final index = await _loadIndex();
    if (index == null) return null;
    final files = index['files'] as Map<String, dynamic>;
    final rawRecord = files[path];
    if (rawRecord is! Map) return null;
    final record = Map<String, dynamic>.from(rawRecord);
    final chunkId = (record['chunk'] as num).toInt();
    final offset = (record['offset'] as num).toInt();
    final length = (record['length'] as num).toInt();
    final chunk = await _readChunk(index, chunkId);
    if (offset < 0 || length < 0 || offset + length > chunk.length) {
      throw const FormatException('Ganjoor source range is out of bounds');
    }
    final bytes = chunk.sublist(offset, offset + length);
    return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  }
}

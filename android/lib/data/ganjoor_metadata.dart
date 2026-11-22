import 'dart:convert';
import 'dart:io';

import 'ganjoor_pack.dart';

/// Schema-v4 Ganjoor reference data. The compressed offline pack is the
/// primary source; jsDelivr is used only when the pack is not installed.
class GanjoorMetadata {
  static const _base =
      'https://cdn.jsdelivr.net/gh/ganjoor/ganjoor-data@main/';
  static final Map<String, Future<List<Map<String, dynamic>>>> _cache = {};

  static Future<List<Map<String, dynamic>>> _load(String path) {
    return _cache.putIfAbsent(path, () async {
      try {
        final packed = await GanjoorPack.readValue(path);
        if (packed is List) {
          return packed.whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
        }
      } catch (_) {
        // Continue with the online source if the optional pack is unavailable.
      }
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 12);
      try {
        final request = await client.getUrl(Uri.parse('$_base$path'));
        request.headers.set(HttpHeaders.acceptHeader, 'application/json');
        final response = await request.close().timeout(
          const Duration(seconds: 25),
        );
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw HttpException('Ganjoor metadata HTTP ${response.statusCode}');
        }
        final decoded = jsonDecode(await utf8.decoder.bind(response).join());
        if (decoded is! List) {
          throw const FormatException('Ganjoor metadata must be a JSON array');
        }
        return decoded.whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList(growable: false);
      } finally {
        client.close(force: true);
      }
    });
  }

  static Future<List<Map<String, dynamic>>> devices() =>
      _load('literary-devices.json');
  static Future<List<Map<String, dynamic>>> concepts() =>
      _load('literary-concepts.json');
  static Future<List<Map<String, dynamic>>> people() => _load('people.json');
  static Future<List<Map<String, dynamic>>> locations() =>
      _load('locations.json');
  static Future<List<Map<String, dynamic>>> sources() =>
      _load('literary-sources.json');
}

/// Renders the literary and historical annotations attached to one couplet.
/// All IDs are resolved against the official Ganjoor dictionaries; no
/// annotation text or interpretation is invented by Souren.
class GanjoorCoupletAnnotations extends StatelessWidget {
  final List<Map<String, dynamic>> literaryTags;
  final List<Map<String, dynamic>> contextTags;
  final List<String> lines;

  const GanjoorCoupletAnnotations({
    super.key,
    this.literaryTags = const [],
    this.contextTags = const [],
    required this.lines,
  });

  static int _id(dynamic value) =>
      value is num ? value.toInt() : int.tryParse(value?.toString() ?? '') ?? -1;

  @override
  Widget build(BuildContext context) {
    if (literaryTags.isEmpty && contextTags.isEmpty) {
      return const SizedBox.shrink();
    }
    final colors = Theme.of(context).colorScheme;
    return FutureBuilder<List<List<Map<String, dynamic>>>>(
      future: Future.wait([
        GanjoorMetadata.devices(),
        GanjoorMetadata.concepts(),
        GanjoorMetadata.people(),
        GanjoorMetadata.locations(),
        GanjoorMetadata.sources(),
      ]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        final devices = {for (final row in snapshot.data![0]) _id(row['Id']): row};
        final concepts = {for (final row in snapshot.data![1]) _id(row['Id']): row};
        final people = {for (final row in snapshot.data![2]) _id(row['Id']): row};
        final locations = {for (final row in snapshot.data![3]) _id(row['Id']): row};
        final sources = {
          for (final row in snapshot.data![4])
            row['Key']?.toString() ?? '': row,
        };
        final sections = <Widget>[];

        for (final tag in literaryTags) {
          final device = devices[_id(tag['DeviceId'])];
          if (device == null) continue;
          final slots = (device['Slots'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          final parts = (tag['Parts'] as List? ?? const [])
              .whereType<Map>()
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
          final details = <String>[];
          for (final part in parts) {
            final slotId = _id(part['SlotId']);
            final slot = slots.where((row) => _id(row['Id']) == slotId)
                .firstOrNull;
            final slotName = slot?['Name']?.toString() ?? 'جزء';
            var value = part['Text']?.toString() ?? '';
            final concept = concepts[_id(part['ConceptId'])];
            if (value.isEmpty && concept != null) {
              value = concept['Name']?.toString() ?? '';
            }
            if (value.isEmpty) {
              final misra = _id(part['Misra']);
              final wordStart = _id(part['WordStart']);
              final wordEnd = _id(part['WordEnd']);
              if (misra >= 1 && misra <= lines.length &&
                  wordStart > 0 && wordEnd >= wordStart) {
                final words = lines[misra - 1].split(RegExp(r'\s+'));
                if (wordStart <= words.length) {
                  value = words.skip(wordStart - 1)
                      .take(wordEnd - wordStart + 1).join(' ');
                }
              }
            }
            if (value.isNotEmpty) details.add('$slotName: $value');
          }
          final sourceKey = tag['SourceKey']?.toString() ?? '';
          final source = sources[sourceKey];
          sections.add(
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (tag['Uncertain'] == true)
                        const Padding(
                          padding: EdgeInsets.only(left: 5),
                          child: Icon(Icons.info_outline, size: 13),
                        ),
                      Text(
                        device['Name']?.toString() ?? 'آرایهٔ ادبی',
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: colors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if ((device['Definition']?.toString() ?? '').isNotEmpty)
                    Text(
                      device['Definition'].toString(),
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.6),
                    ),
                  for (final detail in details)
                    Text(
                      detail,
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(color: colors.onSurface, fontSize: 11.5, height: 1.6),
                    ),
                  if (source != null)
                    Text(
                      'منبع: ${source['Name'] ?? source['Key']} · ${source['License'] ?? ''}',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: colors.outline, fontSize: 10),
                    ),
                ],
              ),
            ),
          );
        }

        final contextLabels = <String>[];
        for (final tag in contextTags) {
          final person = people[_id(tag['PersonId'])];
          final location = locations[_id(tag['LocationId'])];
          if (person != null) {
            contextLabels.add('شخص: ${person['Name'] ?? 'نامشخص'}');
          }
          if (location != null) {
            contextLabels.add('مکان: ${location['Name'] ?? 'نامشخص'}');
          }
          for (final key in ['Date', 'DateText', 'HijriDate', 'GregorianDate']) {
            final value = tag[key]?.toString();
            if (value != null && value.trim().isNotEmpty) {
              contextLabels.add('تاریخ: $value');
            }
          }
        }
        if (sections.isEmpty && contextLabels.isEmpty) {
          return const SizedBox.shrink();
        }
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 9),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colors.outlineVariant.withValues(alpha: .7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (literaryTags.isNotEmpty)
                Text(
                  'آرایه‌های ادبی',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ...sections,
              if (contextLabels.isNotEmpty) ...[
                if (sections.isNotEmpty) const SizedBox(height: 8),
                Text(
                  'اشخاص و مکان‌ها',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: colors.onSurface, fontSize: 11, fontWeight: FontWeight.w800),
                ),
                for (final label in contextLabels)
                  Text(
                    label,
                    textDirection: TextDirection.rtl,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 11.5, height: 1.6),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

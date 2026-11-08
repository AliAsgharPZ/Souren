import 'package:flutter/services.dart';

/// Data for a shareable word, proverb or poem card. The same data feeds
/// share text, the share image and the detail sheet.
class ShareCardData {
  /// The headword (Arabic word) or the proverb itself.
  final String title;

  /// Detail lines, one per line (Persian equivalent, meaning, ...).
  final List<String> lines;

  /// Full Ganjoor hierarchy, shown between a verse and its meaning.
  final String? breadcrumb;

  /// Meaning of a couplet, rendered below its breadcrumb.
  final String? meaning;

  /// Extra context, e.g. the category or «ضرب‌المثل فارسی».
  final String? caption;

  const ShareCardData({
    required this.title,
    required this.lines,
    this.breadcrumb,
    this.meaning,
    this.caption,
  });
}

enum ShareFormat { text, image, textAndImage }

enum ShareAction { share, save, copy }

/// The plain-text form of a card: title, detail lines, caption, sign-off.
String buildShareText(ShareCardData card) {
  final parts = <String>[card.title];
  if (card.breadcrumb != null) parts.add(card.breadcrumb!);
  if (card.meaning != null) parts.add(card.meaning!);
  parts.addAll(card.lines);
  if (card.caption != null) parts.add(card.caption!);
  parts.add('— سورن');
  return parts.join('\n');
}

/// Talks to the Android side (MainActivity, channel 'souren/files'):
/// ACTION_SEND for sharing, MediaStore for saving to the gallery or
/// Downloads. No new pub dependency — the image is rendered by Flutter
/// (RepaintBoundary) and handed over as PNG bytes.
class ShareService {
  static const _channel = MethodChannel('souren/files');

  static Future<bool> _call(String method, Map<String, Object> args) async {
    try {
      return await _channel.invokeMethod<bool>(method, args) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> shareText(String text) =>
      _call('shareText', {'text': text});

  static Future<bool> shareImage(Uint8List png, String name) =>
      _call('shareImage', {'bytes': png, 'name': name});

  static Future<bool> shareTextAndImage(
    String text,
    Uint8List png,
    String name,
  ) => _call('shareTextAndImage', {'text': text, 'bytes': png, 'name': name});

  static Future<bool> saveImage(Uint8List png, String name) =>
      _call('saveImage', {'bytes': png, 'name': name});

  static Future<bool> saveText(String text, String name) =>
      _call('saveText', {'text': text, 'name': name});
}

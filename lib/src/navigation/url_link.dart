import 'package:editor/src/model/position.dart';
import 'package:flutter/material.dart';

/// `true`, если [uri] — внешняя веб-ссылка (`http` / `https`).
bool isWebNavigationUri(String uri) {
  final scheme = Uri.tryParse(uri)?.scheme;
  return scheme == 'http' || scheme == 'https';
}

/// Диапазон URL (`http://` / `https://`) под [offset] или `null`.
///
/// Расширяет в обе стороны от точки по [_isUrlChar], затем проверяет префикс
/// `http://` или `https://`. Не распознаёт `www.` без схемы.
Range? urlRangeAt(String text, TextOffset offset) {
  if (text.isEmpty) return null;
  var index = offset;
  if (index >= text.length) index = text.length - 1;
  if (index < 0) return null;

  var start = index;
  while (start > 0 && _isUrlChar(text.codeUnitAt(start - 1))) {
    start--;
  }
  var end = index + 1;
  while (end < text.length && _isUrlChar(text.codeUnitAt(end))) {
    end++;
  }
  if (start >= end) return null;

  final slice = text.characters.getRange(start, end).toString();
  if (!slice.startsWith('http://') && !slice.startsWith('https://')) {
    return null;
  }
  return Range(start, end);
}

/// Допустимый символ URL: буквы, цифры и типичные разделители path/query.
bool _isUrlChar(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return true;
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) return true;
  if (codeUnit >= 0x61 && codeUnit <= 0x7A) return true;
  switch (codeUnit) {
    case 0x2D: // -
    case 0x2E: // .
    case 0x5F: // _
    case 0x2F: // /
    case 0x3A: // :
    case 0x3F: // ?
    case 0x3D: // =
    case 0x26: // &
    case 0x25: // %
    case 0x23: // #
    case 0x7E: // ~
      return true;
    default:
      return false;
  }
}

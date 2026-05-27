import 'package:editor/src/model/position.dart';

/// Возвращает диапазон идентификатора/слова на [offset] или `null`, если его нет.
///
/// Символы слова следуют соглашениям Dart: `$`, `_`, ASCII-буквы и цифры.
/// Поиск расширяется от [offset] (или от предшествующего символа, когда каретка
/// стоит сразу после слова) до самого длинного непрерывного прогона символов слова.
///
/// ```dart
/// final range = wordRangeAt('foo_bar', 4); // Range(0, 7) для всего идентификатора
/// ```
///
/// **Граничные случаи:**
/// - Пустой [text] → `null`.
/// - [offset] на конце или за ним ограничивается последним code unit для поиска.
/// - [offset] на не-словесном символе без слова слева → `null`.
Range? wordRangeAt(String text, TextOffset offset) {
  if (text.isEmpty) return null;
  var index = offset;
  if (index >= text.length) index = text.length - 1;
  if (index < 0) return null;

  if (!_isWordChar(text.codeUnitAt(index))) {
    // Каретка сразу после слова — привязаться к символу слева.
    if (offset > 0 && _isWordChar(text.codeUnitAt(offset - 1))) {
      index = offset - 1;
    } else {
      return null;
    }
  }

  var start = index;
  while (start > 0 && _isWordChar(text.codeUnitAt(start - 1))) {
    start--;
  }

  var end = index + 1;
  while (end < text.length && _isWordChar(text.codeUnitAt(end))) {
    end++;
  }

  return start < end ? Range(start, end) : null;
}

/// Символ входит в «слово» по правилам Dart: `$`, `_`, буквы, цифры.
bool _isWordChar(int codeUnit) {
  if (codeUnit >= 0x30 && codeUnit <= 0x39) return true; // 0-9
  if (codeUnit >= 0x41 && codeUnit <= 0x5A) return true; // A-Z
  if (codeUnit >= 0x61 && codeUnit <= 0x7A) return true; // a-z
  return codeUnit == 0x5F || codeUnit == 0x24; // _ $
}

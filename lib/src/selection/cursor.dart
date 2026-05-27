import 'package:editor/src/model/document.dart';
import 'package:editor/src/model/position.dart';

/// Смещает [offset] на одну кодовую единицу UTF-16 влево, с ограничением до 0.
///
/// Не реализует переход влево по графемным кластерам (один «символ» может занимать две единицы).
TextOffset cursorMoveLeft(Document _, TextOffset offset) {
  if (offset <= 0) return 0;
  return offset - 1;
}

/// Смещает [offset] на одну кодовую единицу UTF-16 вправо, с ограничением до [Document.length].
TextOffset cursorMoveRight(Document doc, TextOffset offset) {
  if (offset >= doc.length) return doc.length;
  return offset + 1;
}

/// Начало «текста» на строке: первый символ после ведущих пробелов и табов.
///
/// Пустая строка и строка только из отступов дают столбец 0.
int _lineContentStartColumn(String lineContent) {
  for (var col = 0; col < lineContent.length; col++) {
    final code = lineContent.codeUnitAt(col);
    if (code != 0x20 && code != 0x09) return col;
  }
  return 0;
}

/// Перемещает каретку к началу текста на строке с учётом отступов (пробел, таб).
///
/// Поведение как в типичных IDE (Home):
/// - правее первого непробельного — к нему;
/// - в отступе — к первому непробельному;
/// - уже на первом символе текста при ненулевом отступе — к столбцу 0;
/// - на столбце 0 — без изменений.
TextOffset cursorLineStart(Document doc, TextOffset offset) {
  final pos = doc.positionAt(offset);
  final line = pos.line;
  final hardStart = doc.lineStart(line);
  final contentEnd = doc.lineContentEnd(line);
  if (hardStart >= contentEnd) return hardStart;

  final lineContent = doc.getText(Range(hardStart, contentEnd));
  final contentStart = hardStart + _lineContentStartColumn(lineContent);

  if (offset > contentStart) return contentStart;
  if (offset > hardStart && offset < contentStart) return contentStart;
  if (offset == contentStart && contentStart > hardStart) return hardStart;
  return hardStart;
}

/// Смещение после последней содержимой кодовой единицы строки (перед переводом строки).
TextOffset cursorLineEnd(Document doc, TextOffset offset) {
  final pos = doc.positionAt(offset);
  return doc.lineContentEnd(pos.line);
}

/// Переходит на предыдущую строку, стремясь к [desiredColumn].
///
/// Фактический столбец — `min(desiredColumn, длина содержимого строки)`; желаемый
/// столбец при укорочении строки не сбрасывается (хранится снаружи).
/// На строке 0 возвращает 0.
TextOffset cursorMoveUp(
  Document doc,
  TextOffset offset,
  int desiredColumn,
) {
  final pos = doc.positionAt(offset);
  if (pos.line == 0) return 0;
  final prevLine = pos.line - 1;
  final prevStart = doc.lineStart(prevLine);
  final maxCol = doc.lineContentEnd(prevLine) - prevStart;
  final col = desiredColumn < maxCol ? desiredColumn : maxCol;
  return doc.offsetAt(Position(prevLine, col));
}

/// Переходит на следующую строку, стремясь к [desiredColumn].
///
/// На последней строке возвращает [Document.length] (конец документа).
TextOffset cursorMoveDown(
  Document doc,
  TextOffset offset,
  int desiredColumn,
) {
  final pos = doc.positionAt(offset);
  if (pos.line >= doc.lineCount - 1) return doc.length;
  final nextLine = pos.line + 1;
  final nextStart = doc.lineStart(nextLine);
  final maxCol = doc.lineContentEnd(nextLine) - nextStart;
  final col = desiredColumn < maxCol ? desiredColumn : maxCol;
  return doc.offsetAt(Position(nextLine, col));
}

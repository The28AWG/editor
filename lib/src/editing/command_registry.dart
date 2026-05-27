import 'package:editor/src/editing/commands/backspace_command.dart';
import 'package:editor/src/editing/commands/cut_command.dart';
import 'package:editor/src/editing/commands/delete_command.dart';
import 'package:editor/src/editing/commands/editor_command.dart';
import 'package:editor/src/editing/commands/insert_newline_command.dart';
import 'package:editor/src/editing/commands/insert_tab_command.dart';
import 'package:editor/src/editing/commands/paste_command.dart';
import 'package:editor/src/editing/commands/type_character_command.dart';
import 'package:editor/src/editing/editor_config.dart';
import 'package:editor/src/editing/transaction.dart';
import 'package:editor/src/model/document_change.dart';

/// Сопоставляет имена команд с фабриками [EditorCommand].
///
/// ## Встроенные имена
///
/// | Name | Command |
/// |------|---------|
/// | `typeCharacter` | [TypeCharacterCommand] (requires `character` arg) |
/// | `backspace` | [BackspaceCommand] |
/// | `delete` | [DeleteCommand] |
/// | `insertNewline` | [InsertNewlineCommand] |
/// | `insertTab` | [InsertTabCommand] |
/// | `paste` | [PasteCommand] (requires `pasteText` arg) |
/// | `cut` | [CutCommand] |
///
/// Хосты расширяют реестр через [register]. [EditorController.executeCommand] делегирует сюда.
///
/// Возвращает `null`, если имя неизвестно или у `typeCharacter` нет символа.
final class CommandRegistry {
  CommandRegistry({EditorConfig? config})
    : config = config ?? const EditorConfig() {
    _registerBuiltins();
  }

  final EditorConfig config;
  final Map<String, EditorCommand Function()> _factories = {};

  /// Регистрирует встроенные команды в конструкторе.
  void _registerBuiltins() {
    register('backspace', BackspaceCommand.new);
    register('delete', DeleteCommand.new);
    register('insertNewline', InsertNewlineCommand.new);
    register('insertTab', InsertTabCommand.new);
    register('cut', CutCommand.new);
  }

  /// Регистрирует фабрику команды по строковому [name] (перезаписывает одноимённую).
  void register(String name, EditorCommand Function() factory) {
    _factories[name] = factory;
  }

  /// Выполняет команду [name]; для `typeCharacter` нужен непустой [character].
  DocumentChange? execute(
    Transaction engine,
    String name, {
    String? character,
    String? pasteText,
  }) {
    if (name == 'typeCharacter') {
      if (character == null || character.isEmpty) return null;
      return TypeCharacterCommand(character).execute(engine, config);
    }
    if (name == 'paste') {
      if (pasteText == null || pasteText.isEmpty) return null;
      return PasteCommand(pasteText).execute(engine, config);
    }
    final factory = _factories[name];
    if (factory == null) return null;
    return factory().execute(engine, config);
  }
}

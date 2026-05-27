import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ctrl на desktop/Linux/Windows, Cmd на macOS — как в VS Code для «перейти к определению».
bool linkModifierPressed() {
  final keys = HardwareKeyboard.instance;
  if (defaultTargetPlatform == TargetPlatform.macOS) {
    return keys.isMetaPressed;
  }
  return keys.isControlPressed;
}

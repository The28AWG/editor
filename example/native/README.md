# Нативная сборка tree-sitter для `example`

Здесь собираются **две** динамические библиотеки для быстрой синтаксической подсветки Dart (первая «волна» перед LSP):

| Файл | Назначение |
|------|------------|
| `libtree-sitter.so` / `.dylib` | Ядро tree-sitter (FFI пакета `tree_sitter`) |
| `libtree_sitter_dart.so` / `.dylib` | Грамматика Dart, символ `tree_sitter_dart` |

После сборки артефакты лежат в:

```text
example/native/out/<платформа>/
  libtree-sitter.so
  libtree_sitter_dart.so
```

Поддерживаемые каталоги `<платформа>` (desktop, `make`):

- `linux-x64`, `linux-arm64`
- `macos-x64`, `macos-arm64`

**Android** (`make android`) — отдельная раскладка:

```text
example/native/out/jniLibs/
  arm64-v8a/libtree-sitter.so
  arm64-v8a/libtree_sitter_dart.so
  armeabi-v7a/...
  x86_64/...          # эмулятор
```

Каталоги `third_party/` и `out/` в git не попадают (см. `.gitignore`).

**IDE:** каталог `example/native` исключён из анализа Dart/DCM и из лишнего наблюдения Git/файловой системы (см. `.vscode/settings.json` в корне репо и в `example/`). После `make deps` вложенные каталоги `.git` в `third_party/` удаляются, чтобы Cursor/VS Code не открывали клоны как отдельные репозитории.

**Git:** `third_party/` и `out/` в `.gitignore` (корень репо и `native/.gitignore`).

---

## Требования

| Инструмент | Зачем |
|------------|--------|
| **git** | Клонирование tree-sitter и tree-sitter-dart |
| **make** | Запуск сборки |
| **clang** или **gcc** | Компиляция C |
| **Dart SDK** | `make verify` и запуск example |
| **Flutter** (для приложения) | `flutter run` после сборки нативной части |

Опционально:

- **Node.js 18+** и `npx tree-sitter` — только если в клоне грамматики нет `src/parser.c` (редкий случай).

Проверка:

```bash
git --version
make --version
clang --version   # или gcc --version
dart --version
```

---

## Несколько платформ (desktop + Android)

**Очищать `native/` между платформами не нужно.**

| Команда | Куда кладёт артефакты | Исходники |
|---------|------------------------|-----------|
| `make` | `out/linux-x64/` (или macOS) | общий `third_party/` |
| `make android` | `out/jniLibs/<abi>/` | тот же `third_party/` |

Типичный порядок: `make && make verify`, затем `make android && make verify-android`. Или только Android, если desktop не нужен.

`make clean` — только `out/`. `make clean-all` — ещё и `third_party/` (полная перекачка git).

---

## Быстрый старт (Linux / macOS)

Из корня репозитория редактора:

```bash
cd example/native
make
make verify
```

Если `make verify` печатает `OK: tree-sitter Dart grammar loaded`, нативная часть готова.

Запуск Flutter (Linux desktop):

```bash
cd example
flutter run -d linux
```

При сборке приложения CMake копирует `.so` / `.dylib` из `native/out/<платформа>/` в `build/.../bundle/lib/`, откуда их подхватывает Dart.

---

## Пошаговая сборка

### 1. Перейти в каталог native

```bash
cd example/native
```

### 2. Собрать библиотеки

```bash
make
```

Что происходит:

1. В `third_party/` клонируются:
   - [tree-sitter](https://github.com/tree-sitter/tree-sitter) — версия в `versions.mk` (`TREE_SITTER_VERSION`, по умолчанию `v0.24.7`);
   - [tree-sitter-dart](https://github.com/UserNobody14/tree-sitter-dart) — ref в `versions.mk` (`TREE_SITTER_DART_REF`).
2. Собирается `libtree-sitter` в `third_party/tree-sitter`.
3. Линкуется `libtree_sitter_dart` с `src/parser.c` (+ `scanner.c`, если есть).

Узнать обнаруженную платформу:

```bash
make print-platform
```

### 3. Проверить сборку

```bash
make verify
```

Скрипт делает две вещи:

1. **Shell** — файлы `.so` и символы `tree_sitter_dart` / `external_scanner_create` (`scripts/verify_native_libs.sh`).
2. **`flutter test test/tree_sitter_native_test.dart`** — загрузка библиотек и пробный parse.

Не используйте `dart run tool/verify_tree_sitter_native.dart` на **Dart 3.12+**: компилятор падает на FFI в пакете `tree_sitter` (`InvalidType` / `FunctionType`). Приложение через `flutter run` при этом собирается нормально.

Только shell-проверка:

```bash
make verify-native
```

### 4. Запустить example

```bash
cd example
flutter run -d linux    # или macos
```

---

## Переменные окружения (Dart)

| Переменная | Значение |
|------------|----------|
| `TREE_SITTER_NATIVE_DIR` | Абсолютный или относительный путь к `native/out/<платформа>` (приоритет при разработке) |

Пример:

```bash
export TREE_SITTER_NATIVE_DIR=/path/to/editor/example/native/out/linux-x64
dart run tool/verify_tree_sitter_native.dart
```

Без переменной Dart ищет `example/native/out/<платформа>/` относительно корня example (по `pubspec.yaml`). В собранном Flutter-бандле библиотеки берутся из `lib/` рядом с исполняемым файлом.

---

## Цели Makefile

| Команда | Действие |
|---------|----------|
| `make` / `make all` | Собрать обе библиотеки в `out/<платформа>/` |
| `make deps` | Только клонировать `third_party/` |
| `make verify` | `make` + проверочный Dart-скрипт |
| `make sync-queries` | Скопировать `highlights.scm` из клона грамматики в `native/queries/` |
| `make print-platform` | Вывести имя платформы (`linux-x64`, …) |
| `make clean` | Удалить `out/` |
| `make clean-all` | Удалить `out/` и `third_party/` |
| `make help` | Краткая справка |

---

## Версии и обновление

Пины заданы в [`versions.mk`](versions.mk):

- `TREE_SITTER_VERSION` — тег tree-sitter;
- `TREE_SITTER_DART_REF` — ветка/тег tree-sitter-dart;
- `TREE_SITTER_DART_ENTRY` — имя символа (`tree_sitter_dart`).

После смены версий:

```bash
make clean-all
make
make verify
```

При обновлении грамматики можно обновить запрос подсветки:

```bash
make deps
make sync-queries
```

---

## Интеграция с Flutter (Linux)

В [`example/linux/CMakeLists.txt`](../linux/CMakeLists.txt) при наличии файлов в `native/out/<платформа>/` они устанавливаются в `bundle/lib/`. Если библиотек нет, приложение **соберётся**, но быстрая tree-sitter-подсветка будет недоступна (останется только LSP).

Перед первым `flutter run` на новой машине или после `flutter clean` снова выполните `make` в `example/native`.

---

## Android

Сборка на **Linux или macOS** с установленным **Android NDK** (через Android Studio → SDK Manager → NDK).

### Требования

| Переменная / путь | Зачем |
|-------------------|--------|
| `ANDROID_NDK_HOME` или `ANDROID_HOME/ndk/<версия>` | NDK toolchain |
| `git`, `make` | Как для desktop |

### Сборка

```bash
cd example/native
make android
make verify-android
```

Скрипт `scripts/build_android.sh` кросс-компилирует tree-sitter **v0.25.6+** и грамматику Dart для ABI:

- `arm64-v8a` — основные устройства;
- `armeabi-v7a` — старые ARM;
- `x86_64` — эмулятор Android.

Gradle подхватывает `native/out/jniLibs` (см. `android/app/build.gradle.kts`).

### Запуск

```bash
cd example
flutter run -d <android-device>
```

В AppBar: `tree-sitter: on` (если `.so` попали в APK). LSP на Android по-прежнему зависит от наличия `dart` на устройстве/эмуляторе — обычно **недоступен**; быстрая подсветка tree-sitter работает автономно.

### Проверка без устройства

```bash
make verify-android
```

### Переменные

| Переменная | Значение |
|------------|----------|
| `ANDROID_API` | Уровень API для clang (по умолчанию `24`) |
| `TREE_SITTER_ANDROID_ABI` | При отладке: явный каталог `arm64-v8a` и т.д. |

---

## macOS

Те же команды в `example/native`:

```bash
make
make verify
cd ..
flutter run -d macos
```

На Apple Silicon обычно `PLATFORM=macos-arm64`, артефакты — `.dylib`.

Если macOS блокирует загрузку неподписанных библиотек, для локальной разработки может понадобиться:

```bash
xattr -cr native/out/macos-arm64/*.dylib
```

(Только для dev-сборки.)

---

## Windows

Автоматический `Makefile` рассчитан на Linux и macOS. Для Windows потребуется отдельная схема (MSVC, `.dll`, копирование в `runner/Debug`). Пока используйте Linux/macOS desktop или WSL2:

```bash
# в WSL2
cd example/native && make && make verify
cd .. && flutter run -d linux
```

---

## Устранение неполадок

### `Missing .../src/parser.c`

В клоне грамматики нет сгенерированного парсера:

```bash
cd third_party/tree-sitter-dart
npx tree-sitter generate
cd ../..
make
```

### `Failed to set language using the provided shared library`

Грамматика собрана под **другую** версию tree-sitter (ABI). `tree-sitter-dart` на `master` требует **tree-sitter >= 0.25** (LANGUAGE_VERSION 15). В `versions.mk` задано `TREE_SITTER_VERSION=v0.25.6`.

```bash
make clean-all
make
make verify
```

### `undefined symbol: tree_sitter_dart_external_scanner_create`

Грамматика собрана **без** `src/scanner.c` (часто после первого `make` до исправления Makefile). Пересоберите:

```bash
cd example/native
make clean
make
make verify
cd ..
flutter clean
flutter run -d linux
```

### `Failed to set language using the provided shared library`

- Пересоберите: `make clean-all && make`.
- Убедитесь, что `libtree-sitter` и `libtree_sitter_dart` из **одной** сборки `make` (один каталог `out/<платформа>/`).
- Проверьте `make verify` с явным `TREE_SITTER_NATIVE_DIR`.

### `libtree-sitter.so: cannot open shared object file` при `make verify`

Задайте runpath или LD_LIBRARY_PATH на время проверки:

```bash
export TREE_SITTER_NATIVE_DIR="$(pwd)/out/linux-x64"
export LD_LIBRARY_PATH="$TREE_SITTER_NATIVE_DIR${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
cd .. && dart run tool/verify_tree_sitter_native.dart
```

`make verify` выставляет `TREE_SITTER_NATIVE_DIR` автоматически; на Linux при необходимости добавьте `LD_LIBRARY_PATH` как выше.

### Flutter собрался, но tree-sitter не работает

1. Есть ли файлы в `native/out/$(make -C native print-platform)/`?
2. Был ли `flutter run` **после** `make`?
3. Для Linux: в bundle должны быть оба файла в `build/linux/.../bundle/lib/`.

### Несовместимость версий tree-sitter и грамматики

Используйте пины из `versions.mk`. Смешивание tree-sitter 0.26+ с старой грамматикой без пересборки parser часто ломает `ts_parser_set_language`.

---

## Связанные файлы в проекте

| Путь | Роль |
|------|------|
| `native/Makefile` | Сборка |
| `native/versions.mk` | Версии upstream |
| `native/queries/highlights.scm` | Запрос подсветки (для Dart-кода) |
| `lib/tree_sitter/tree_sitter_native_config.dart` | Поиск библиотек |
| `tool/verify_tree_sitter_native.dart` | Проверка после `make` |
| `linux/CMakeLists.txt` | Установка в Flutter bundle |

Дальнейшая двухволновая подсветка (tree-sitter + LSP semantic tokens) подключается в Dart поверх этих библиотек.

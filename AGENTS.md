# AGENTS.md

## Project Overview

Dart CLI tool for renaming media libraries to comply with Jellyfin naming conventions.
SDK: `>=3.8.0 <4.0.0`. Linting: `very_good_analysis` with 80-char line limit.

## Build/Lint/Test Commands

- **Install dependencies**: `dart pub get`
- **Generate code (JSON serialization)**: `dart run build_runner build`
- **Watch for code gen changes**: `dart run build_runner watch`
- **Run linter**: `dart analyze`
- **Format code**: `dart format .`
- **Format single file**: `dart format path/to/file.dart`
- **Check format without modifying**: `dart format --output=none --set-exit-if-changed .`
- **Run all tests**: `dart test`
- **Run single test file**: `dart test test/scanner_test.dart`
- **Run tests matching name pattern**: `dart test --name "pattern"`
- **Build CLI executable**: `dart compile exe bin/main.dart`
- **Run built executable**: `./bin/main.exe <command> [args]`

## Project Structure

```
bin/main.dart          # CLI entry point using CommandRunner
lib/
  cli/commands.dart    # CLI command definitions (scan, rename, rename-single, undo)
  config/              # Constants (file extensions, filter words)
  core/
    detector.dart      # Basic media type detection from file patterns
    grouper.dart       # Groups TV show items by name across directories
    renamer.dart       # Main rename logic (plan + execute operations)
    scanner.dart       # Recursive media file scanning + episode parsing
    undo.dart          # JSON undo log with human-readable header + machine JSON
  metadata/
    interactive.dart   # Interactive terminal prompts for user input
    models.dart        # Data models (Movie, TvShow, Season, Episode, MediaItem)
    models.g.dart      # Generated JSON serialization (json_serializable)
  utils/
    logger.dart        # AppLogger wrapper around dart:logging
    season_parser.dart # Season number extraction from directory names
    sort_utils.dart    # Natural sort comparison
    title_processor.dart # Title extraction/cleaning from filenames
test/                  # Unit tests using package:test
```

## Code Style Guidelines

### General
- Follow Dart style guide and effective Dart guidelines
- Linting enforced by `very_good_analysis` package (strict rules)
- 80 character line limit enforced by linter
- All public APIs must have `///` documentation comments

### Naming Conventions
- `camelCase` for variables, methods, parameters, and fields
- `PascalCase` for classes, enums, and typedefs
- `snake_case` for file names (e.g., `season_parser.dart`)
- Private members prefixed with `_` (e.g., `_logger`, `_plannedOperations`)
- Constants use `camelCase` (e.g., `filenameFilterWords`)
- Enum values use `camelCase` (e.g., `MediaType.movie`, `RenameMode.hardLink`)

### Types
- Use type annotations for all variables, parameters, and return types
- Prefer `final` for local variables that are not reassigned
- Use `var` only when the type is obvious or reassigned
- Use nullable types (`?`) explicitly, avoid dynamic
- Use records for multi-value returns: `({String? title, int? year})`
- Use `List<T>`, `Map<K,V>`, `Set<T>` with explicit type parameters

### Imports
- Order: `dart:*`, `package:*`, relative imports
- Use `as` prefix for conflicting names (e.g., `import 'package:path/path.dart' as path;`)
- Use `as app_logger` for the logger package import to avoid conflicts
- Avoid unnecessary imports

### Error Handling
- Use `try-catch` with specific exception types where possible
- Catch `FileSystemException` for file operations, `FormatException` for parsing
- Use `on Object catch (e)` as the general catch pattern (not bare `catch (e)`)
- Log errors using `AppLogger` methods (`error()`, `warning()`, `debug()`)
- Call `exit(1)` for fatal CLI errors after logging
- Rethrow when caller needs to handle the error

### File Operations
- Use `package:path/path.dart` for all path manipulation (never string splitting)
- Use `path.join()`, `path.dirname()`, `path.basename()`, `path.extension()`
- Use `path.canonicalize()` for path comparison
- Handle cross-platform path separators via `Platform.pathSeparator`
- Always check `existsSync()` before file operations
- Use `Directory(dir).create(recursive: true)` for nested directories

### Logging
- Use `AppLogger` (wraps `dart:logging`) instead of `print` statements
- Levels: `_logger.info()`, `_logger.warning()`, `_logger.error()`, `_logger.debug()`
- Include context in log messages (file paths, counts, state)
- Use `_logger.debug()` for verbose/diagnostic output

### Data Models
- Use `@JsonSerializable()` for models needing JSON serialization
- Include `fromJson` factory constructor and `toJson` method
- Run `dart run build_runner build` after model changes
- Implement `copyWith()` on immutable models (like `MediaItem`)
- Use `enum` for fixed sets of values with doc comments on each value

### CLI Commands
- Extend `Command<void>` from `package:args/command_runner.dart`
- Use `argParser.addOption()`/`addFlag()` in constructor
- Define `name`, `description`, and `aliases` getters
- Use `argResults?['option']` with null-aware access
- Share logic via abstract base classes (e.g., `BaseRenameCommand`)

### Testing
- Test framework: `package:test`
- Test file naming: `<feature>_test.dart`
- Use `group()` to organize tests by class/feature
- Use descriptive test names: `test('should parse standard SxxExx format', ...)`
- Use `expect()` with matchers: `isNotNull`, `equals()`, `isNull`
- Test both positive and negative cases
- Use `reason:` parameter in expect for complex assertions

### JSON/Configuration
- Use `json_serializable` + `json_annotation` for serialization
- Run build_runner after model changes
- Undo logs use hybrid format: human-readable header + JSON data section
- Use `JsonEncoder.withIndent('  ')` for pretty-printed JSON

### Cross-Platform
- Handle Windows vs Unix paths via `Platform.pathSeparator`
- Use `dart:io` `Platform` checks for OS-specific logic
- Hard links: use `mklink /H` on Windows, `ln` on Unix
- Consider encoding when reading file names from filesystem

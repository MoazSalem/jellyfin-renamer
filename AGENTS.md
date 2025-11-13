# AGENTS.md

## Build/Lint/Test Commands
- **Install dependencies**: `dart pub get`
- **Run linter**: `dart analyze`
- **Format code**: `dart format .`
- **Run tests**: `dart test`
- **Run single test**: `dart test path/to/test_file.dart`
- **Build CLI executable**: `dart compile exe bin/main.dart`

## Code Style Guidelines
- Follow the Dart style guide and effective Dart guidelines
- Use type annotations for all variables, parameters, and return types
- Use camelCase for variables and methods, PascalCase for classes
- Handle exceptions with try-catch blocks and specific exception types
- Use the `path` package for file operations instead of string manipulation
- Import packages in this order: dart:*, package:, relative imports
- Use string interpolation with `$` for simple variables, `${}` for expressions
- Add documentation comments (///) to all public APIs
- Use logging package instead of print statements for user feedback
- Validate command-line arguments and file paths before processing
- For media file operations, always preserve original paths in undo logs before renaming
- Use JSON for configuration and logging data structures
- Handle filesystem encoding properly for cross-platform compatibility
- Support subtitle files (.srt, .sub, .ass, .ssa, .vtt) alongside video files
- Use directory-based grouping for TV show episodes instead of filename prefix matching
- Ensure undo operations handle both video and subtitle files with proper error recovery
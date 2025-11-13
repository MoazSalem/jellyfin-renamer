# AGENTS.md

## Build/Lint/Test Commands
- **Install dependencies**: `dart pub get`
- **Generate code**: `dart run build_runner build`
- **Run linter**: `dart analyze`
- **Format code**: `dart format .`
- **Run tests**: `dart test`
- **Run single test**: `dart test path/to/test_file.dart`
- **Build CLI executable**: `dart compile exe bin/main.dart`

## Code Style Guidelines
- Follow Dart style guide and effective Dart guidelines
- Use type annotations for all variables, parameters, and return types
- Use camelCase for variables/methods, PascalCase for classes
- Handle exceptions with try-catch blocks and specific exception types
- Use `path` package for file operations instead of string manipulation
- Import order: dart:*, package:, relative imports
- String interpolation: `$` for simple variables, `${}` for expressions
- Add documentation comments (///) to all public APIs
- Use logging package instead of print statements for user feedback
- Validate command-line arguments and file paths before processing
- Preserve original paths in undo logs before renaming media files
- Use JSON for configuration and logging data structures
- Handle filesystem encoding properly for cross-platform compatibility
- Support subtitle files (.srt, .sub, .ass, .ssa, .vtt) alongside video files
- Use directory-based grouping for TV show episodes
- Ensure undo operations handle both video and subtitle files with proper error recovery
- Linting: Uses very_good_analysis package with strict rules (80 char line limit, etc.)
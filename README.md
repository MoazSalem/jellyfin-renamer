# Jellyfin Media Library Renamer

A command-line tool for renaming media libraries to comply with [Jellyfin's official naming conventions](https://jellyfin.org/docs/general/server/media/) for both TV Shows and Movies.

## Features

- **Automatic Detection**: Scans directories and automatically detects whether files are movies or TV episodes
- **Smart Grouping**: Groups multiple episodes from the same TV show for efficient processing using directory-based organization
- **Directory-Aware**: Intelligently extracts show names from folder names, parent directories, and filename patterns
- **Subtitle Support**: Automatically detects and renames subtitle files (.srt, .sub, .ass, .ssa, .vtt) alongside video files
- **Jellyfin Compliance**: Renames files and creates proper folder structures following Jellyfin standards
- **Dry Run Mode**: Preview changes before applying them
- **Enhanced Undo System**: Complete undo capability with human-readable logs, proper error handling, and automatic cleanup
- **Interactive Mode**: Intelligent prompts showing detected metadata, file information, and prioritized naming options
- **Cross-Platform**: Works on Windows, Linux, and macOS

## Installation

1. Ensure you have Dart SDK installed
2. Clone or download this repository
3. Run `dart pub get` to install dependencies
4. Build the executable: `dart compile exe bin/main.dart`

## Testing

The `testing_playground/` directory contains sample media files and directory structures for testing the tool. Use these for development and testing:

```bash
# Basic functionality test
renamer scan --path testing_playground/test_media

# Episode grouping test
renamer rename --path testing_playground/test_7_episodes --dry-run

# Directory-aware detection test
renamer rename --path "testing_playground/Anne With An E/Anne.With.An.E.Season.1.S01.720p.WEBRip.x265" --dry-run
```

## Usage

### Scan Directory

Scan a directory for media files and detect their types:

```bash
renamer scan --path /path/to/media
```

The scan command shows detailed information including associated subtitle files:

```
INFO: Found 1 media items:
INFO:   MediaType.movie: path/to/Inception.2010.mkv
INFO:     Subtitles: 2
INFO:       path/to/Inception.2010.srt
INFO:       path/to/Inception.2010.English.srt
```

### Rename Files (Dry Run)

Preview what would be renamed without making changes:

```bash
renamer rename --path /path/to/media --dry-run
```

### Rename Files (Apply Changes)

Apply the renaming with interactive prompts:

```bash
renamer rename --path /path/to/media
```

The interactive mode intelligently groups episodes and shows multiple naming options from directory structure:

```
📺 Found 7 episode files in directory: Anne With An E Season 1 [WEBRip]
  • Anne.S01E01.mkv → Season 1, Episode 1
  • Anne.S01E02.mkv → Season 1, Episode 2
  • Anne.S01E03.mkv → Season 1, Episode 3
  • Anne.S01E04.mkv → Season 1, Episode 4
  • Anne.S01E05.mkv → Season 1, Episode 5
  • Anne.S01E06.mkv → Season 1, Episode 6
  • Anne.S01E07.mkv → Season 1, Episode 7

Detected show name options:
1. Anne With An E          ← Parent directory (most likely correct)
2. Anne 720p WEBRip x265   ← Current directory
3. Enter different show name
4. Skip these files
```

Skip interactive prompts (uses detected metadata):

```bash
renamer rename --path /path/to/media --no-interactive
```

### Undo Changes

Revert previous rename operations:

```bash
renamer undo
```

Preview what would be undone:

```bash
renamer undo --preview
```

## Naming Conventions

### Movies

Movies are organized as:
```
/Movies/
└── Movie Name (Year)/
    ├── Movie Name (Year).mkv
    └── Movie Name (Year).default.srt
```

Example:
```
/Movies/
└── Inception (2010)/
    ├── Inception (2010).mkv
    └── Inception (2010).default.srt
```

### TV Shows

TV shows are organized as:
```
/TV Shows/
└── Show Name (Year)/
    └── Season 01/
        ├── Show Name (Year) S01E01 Episode Title.mkv
        └── Show Name (Year) S01E01.default.srt
```

Example:
```
/TV Shows/
└── Breaking Bad (2008)/
    └── Season 01/
        ├── Breaking Bad (2008) S01E01 Pilot.mkv
        └── Breaking Bad (2008) S01E01.default.srt
```

## Command Line Options

### Global Options
- `-v, --verbose`: Show detailed output
- `-h, --help`: Show help information

### Scan Command
- `-p, --path`: Root directory to scan (required)
- `-v, --verbose`: Show detailed output

### Rename Command
- `-p, --path`: Root directory to process (required)
- `-d, --dry-run`: Preview changes without applying them
- `-i, --interactive`: Prompt for confirmation (default: true)
- `-l, --log`: Path to undo log file (default: rename_log.json)
- `-v, --verbose`: Show detailed output

### Undo Command
- `-l, --log`: Path to undo log file (default: rename_log.json)
- `-p, --preview`: Show what will be undone without applying
- `-v, --verbose`: Show detailed output

## File Detection

The tool automatically detects media types based on filename patterns:

- **TV Shows**: Files containing `S01E01`, `S02E05`, etc.
- **Movies**: Files containing years (e.g., `2010`, `2023`)
- **Subtitles**: Files with extensions `.srt`, `.sub`, `.ass`, `.ssa`, `.vtt`
- **Unknown**: Files that don't match these patterns

### Subtitle Association

Subtitle files are automatically associated with video files using intelligent matching:

- **Exact match**: `Movie.mkv` → `Movie.srt`
- **Episode code match**: `Show.S01E01.mkv` → `S01E01.srt`
- **Close name match**: `Movie.mkv` → `Movie.English.srt`
- **Directory-based**: Subtitles in the same folder as videos are associated

## Undo System

All rename operations (including subtitles) are logged to `rename_log.json` with timestamps. The undo command reads this log and reverses all operations in reverse chronological order.

### Enhanced Undo Features

- **Human-readable logs**: The log file includes both human-readable operation summaries and machine-readable JSON
- **Smart error handling**: Only deletes the log file after complete success; preserves logs for partial failures
- **Automatic cleanup**: Removes empty directories created during renaming
- **Progress tracking**: Shows detailed progress during undo operations

**Important**: Always run in dry-run mode first to verify changes before applying them.

## Examples

### Basic Usage

1. **Scan your media directory**:
   ```bash
   renamer scan --path ./media
   ```

2. **Preview changes**:
   ```bash
   renamer rename --path ./media --dry-run
   ```

3. **Apply changes**:
   ```bash
   renamer rename --path ./media
   ```

4. **If something goes wrong, undo**:
   ```bash
   renamer undo
   ```

### Advanced Usage

**Process a large library non-interactively**:
```bash
renamer rename --path /mnt/media --no-interactive --log /var/log/renamer.json
```

**Verbose output for debugging**:
```bash
renamer rename --path ./test --dry-run --verbose
```

## Safety Features

- **Dry-run mode** prevents accidental changes
- **Undo logging** tracks all operations (videos and subtitles) for reversal
- **File validation** ensures paths exist before processing
- **Error handling** gracefully handles permission issues and missing files
- **Smart cleanup** removes empty directories after undo operations
- **Cross-platform paths** work correctly on Windows, Linux, and macOS

## Development

### Running Tests

```bash
# Unit tests
dart test

# Integration testing with sample media
# Use the testing_playground directory for test scenarios
renamer scan --path testing_playground/test_media
renamer rename --path testing_playground/test_7_episodes --dry-run
```

### Building

```bash
dart compile exe bin/main.dart
```

### Code Quality

```bash
dart analyze
dart format .
```

## License

This project is open source. See the license file for details.
# Jellyfin Media Library Renamer

A command-line tool for renaming media libraries to comply with [Jellyfin's official naming conventions](https://jellyfin.org/docs/general/server/media/) for both TV Shows and Movies.

## Features

-   **Advanced TV Show Detection**: Automatically detects episodes from a wide variety of filename and folder structures, including:
    -   Standard `SxxExx` format (`Show.S01E01.mkv`)
    -   Three-Digit format (`Show.101.mkv` for Season 1, Episode 1)
    -   Folder-based numbering (`.../Season 1/01.mkv`)
    -   Multi-Episode Files: Correctly parses and formats files containing multiple episodes from patterns like `S01E01-E02`, `101-102`, and `.../Season 1/01-02.mkv`.
-   **Intelligent TV Show Grouping**:
    -   Scans and groups multiple directories belonging to the same show (e.g., `Breaking Bad (2008)` and `Breaking Bad Season 2`) into a single, streamlined renaming operation.
    -   Performs case-insensitive grouping to correctly identify shows with inconsistent folder names.
    -   Prompts for confirmation before merging grouped shows to ensure accuracy.
-   **Smart Output Directory Logic**: Prevents the creation of nested output folders. When you scan a directory containing just a single show (e.g., `/downloads/The Mentalist Complete/`), the renamed `TV Shows` folder is created alongside it (in `/downloads/`), not inside it.
-   **Comprehensive Subtitle Support**: Automatically detects, matches, and renames a wide variety of subtitle files alongside their corresponding video files.
-   **Jellyfin Compliance**: Renames files and creates proper folder structures following Jellyfin standards
-   **Dry Run Mode**: Preview changes before applying them
-   **Enhanced Undo System**: Complete undo capability with human-readable logs, proper error handling, and automatic cleanup
-   **Interactive Mode**: Intelligent prompts showing detected metadata, file information, and prioritized naming options
-   **Cross-Platform**: Works on Windows, Linux, and macOS

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

### 1. Scan Directory (Optional)

Scan a directory to see what media files the tool detects.

```bash
renamer scan --path /path/to/your/media
```

### 2. Rename Files (Dry Run)

Preview the renaming operations without making any changes. This is the default behavior.

```bash
renamer rename --path /path/to/your/media
```

The interactive mode will guide you through the process, showing detected episodes and providing naming options:

```
📺 Found 2 episode files:
  • T.M.101.rmvb → Season 1, Episode 1
  • T.M.102.rmvb → Season 1, Episode 2

Detected show name options:
1. The Mentalist
2. T M 101
3. Enter different show name
4. Skip these files
Select option: 1

...

📁 Preview of final structure:
└── TV Shows
    └── The Mentalist
        └── Season 01
            ├── The Mentalist S01E01.rmvb
            └── The Mentalist S01E02.rmvb

This is a dry run. No files will be modified.
```

### 3. Apply Changes

To apply the changes, run the `rename` command and confirm at the prompt, or use the `--no-interactive` flag.

```bash
# Run interactively and confirm at the prompt
renamer rename --path /path/to/your/media

# Or, run non-interactively (not recommended until you've done a dry run)
renamer rename --path /path/to/your/media --no-interactive
```

### 4. Undo Changes

If you need to revert the last operation, use the `undo` command.

```bash
renamer undo
```

### Verbose Logging

To enable detailed debug logging for troubleshooting, use the global `--verbose` (`-v`) flag:

```bash
renamer rename --path /path/to/your/media --verbose
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
- `-v, --verbose`: Enable detailed debug logging for troubleshooting.
- `-h, --help`: Show help information

### Scan Command
- `-p, --path`: Root directory to scan (required)

### Rename Command
- `-p, --path`: Root directory to process (required)
- `-d, --dry-run`: Preview changes without applying them
- `-i, --interactive`: Prompt for confirmation (default: true)
- `-l, --log`: Path to undo log file (default: rename_log.json)

### Undo Command
- `-l, --log`: Path to undo log file (default: rename_log.json)
- `-p, --preview`: Show what will be undone without applying

## File Detection

The tool automatically detects media types based on filename patterns:

-   **TV Shows**: Files containing `S01E01`, `S02E05`, three-digit formats like `101` (S01E01), multi-episode formats like `S01E01-E02` or `101-102`, and numbered files within season folders.
-   **Movies**: Files containing years (e.g., `2010`, `2023`)
-   **Subtitles**: Files with extensions `.srt`, `.sub`, `.ass`, `.ssa`, `.vtt`
-   **Unknown**: Files that don't match these patterns

### Subtitle Association

Subtitle files are automatically associated with video files using intelligent matching:

-   **Exact match**: `Movie.mkv` → `Movie.srt`
-   **Episode code match**: `Show.S01E01.mkv` → `S01E01.srt`
-   **Close name match**: `Movie.mkv` → `Movie.English.srt`
-   **Directory-based**: Subtitles in the same folder as videos are associated
-   **Stricter Numeric Matching**: Prevents incorrect associations between purely numeric filenames (e.g., `10.mkv` will not be matched with `1.srt`).

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
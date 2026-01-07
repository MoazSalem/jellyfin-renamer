# Jellyfin Media Library Renamer

A command-line tool for renaming media libraries to comply with [Jellyfin's official naming conventions](https://jellyfin.org/docs/general/server/media/) for both TV Shows and Movies.

<div align=center>
<img height="600" alt="image" src="https://github.com/user-attachments/assets/64b75703-a9a5-4552-af8f-152f423c0581" />
</div>


## Features

-   **Interactive Mode Enhancements**: Users can now edit detected metadata directly from interactive prompts by typing 'e' followed by the option number (e.g., 'e2' to edit the second option).
-   **Advanced TV Show Detection**: Automatically detects episodes from a wide variety of filename and folder structures, including:
    -   Standard `SxxExx` format (`Show.S01E01.mkv`)
    -   `episode xx` format (`Show.episode 01.mkv`)
    -   `eX` or `eXX` format (`Show.e01.mkv`)
    -   Three-Digit format (`Show.101.mkv` for Season 1, Episode 1)
    -   Folder-based numbering (`.../Season 1/01.mkv`, `.../Season One/01.mkv`, `.../First Season/01.mkv`)
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

### From Releases (Recommended)
Download the latest executable for your platform (Windows, Linux, macOS) from the [Releases](https://github.com/MoazSalem/jellyfin-renamer/releases) page.

### From Source
1. Ensure you have Dart SDK installed
2. Clone or download this repository
3. Run `dart pub get` to install dependencies
4. Build the executable: `dart compile exe bin/main.dart`

### Running Globally (Optional)

To run `renamer` from any terminal window without specifying the full path:

#### Windows
1.  Move the downloaded/built `renamer.exe` to a permanent location (e.g., `C:\Users\UserName\bin`).
2.  Open **Start** and search for "Environment Variables".
3.  Click **Edit the system environment variables**.
4.  Click **Environment Variables**.
5.  Under **System variables** (or User variables), find `Path` and click **Edit**.
6.  Click **New** and paste the folder path from step 1.
7.  Click **OK** on all windows.
8.  Restart your terminal. You can now use `renamer` anywhere.

#### Linux / macOS
Move the binary to a directory already in your PATH, such as `/usr/local/bin`:

```bash
# Assuming you are in the directory with the binary
sudo mv renamer /usr/local/bin/
```

Alternatively, add its custom location to your shell config (`.bashrc`, `.zshrc`, etc.):

```bash
export PATH="$PATH:/path/to/directory/containing/renamer"
```

## Testing

To test the tool, you can create a folder with sample media files (videos, subtitles) and run the commands against it.

```bash
# Basic functionality test
renamer scan --path /path/to/test_media

# or using short command

renamer s -p /path/to/test_media

# Dry run to see what happens without renaming
renamer rename --path /path/to/test_media --dry-run

#or using short command

renamer r -p /path/to/test_media --dry-run
```

## Usage

### 1. Scan Directory (Optional)

Scan a directory to see what media files the tool detects.

```bash
renamer scan --path /path/to/your/media
```

- Note that if you don't provide a path, the tool will scan the current directory.

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

### 4. specific Modes (Copy, Hard Link, Soft Link)

By default, the tool moves (renames) files. You can change this behavior using the `--mode` (`-m`) option. This is particularly useful if you want to seed your media from the original location while having a clean structure for Jellyfin.

**Available Modes:**
- `move` (Default): Renames the files.
- `hardlink`: Creates a hard link. Best for seeding; takes up no extra space. (Target and source must be on the same drive).
- `symlink`: Creates a symbolic link (shortcut) - this requires admin permissions on Windows.
- `copy`: Copies the files. (Uses double the storage space).

```bash
# Create hard links
renamer rename --path /path/to/downloads --mode hardlink

# Create symbolic links
renamer rename -p /path/to/downloads -m symlink
```

> [!NOTE]
> The undo log (`rename_log.json`) is **only** generated when using the default `move` mode. Copy, hardlink, and symlink operations do not generate an undo log. Also, empty source directories are **not** deleted in these modes.

### 5. Rename Single Show/Movie

For processing a specific show or movie folder without scanning the entire library structure (useful for downloads folders or specific cleanup).

```bash
renamer rename-single --path "/path/to/downloads/My Show Season 1"
```

This acts exactly like strict mode:
- Errors if multiple movies or mixed content is found.
- Creates the log file inside the target folder (or its parent), keeping logs localized.


### 5. Undo Changes

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

### Scan Command (alias: `s`)
- `-p, --path`: Root directory to scan (required)

### Rename Command (alias: `r`)
- `-p, --path`: Root directory to process (required)
- `-d, --dry-run`: Preview changes without applying them
- `-i, --interactive`: Prompt for confirmation (default: true)
- `-l, --log`: Path to undo log file (default: rename_log.json)
- `-o, --output`: Specific output directory for renamed files. If not specified, uses strict mode logic or scans root.
- `-m, --mode`: Rename mode (move, copy, hardlink, symlink)

### Rename Single Command (alias: `rs`)
- `-p, --path`: Path to the show or movie folder (required)
- `-d, --dry-run`: Preview changes without applying them
- `-i, --interactive`: Prompt for confirmation (default: true)
- `-l, --log`: Path to undo log file (default: rename_log.json)

### Undo Command (alias: `u`)
- `-l, --log`: Path to undo log file (default: rename_log.json)
- `-p, --preview`: Show what will be undone without applying

## File Detection

The tool automatically detects media types based on filename patterns:

-   **TV Shows**: Files containing `S01E01`, `S02E05`, `episode xx` format, `eX/eXX` format, three-digit formats like `101` (S01E01), multi-episode formats like `S01E01-E02` or `101-102`, numbered files within season folders, and word-based season names (e.g., "Season One", "First Season").
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

### Arabic Language Support

The tool now supports Arabic language patterns for detecting season and episode information:

-   **Seasons**: Recognizes Arabic words for seasons, including numeric (e.g., `الموسم 1`, `الموسم واحد`) and ordinal forms (e.g., `الموسم الأول`, `الموسم الثاني`) up to the twentieth season.
-   **Episodes**: Recognizes the Arabic word for episode (`الحلقة`) followed by the episode number (e.g., `الحلقة 1`).

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

# Integration testing
# Create a folder with sample content to test manually
renamer scan --path /path/to/sample_content
renamer rename --path /path/to/sample_content --dry-run
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
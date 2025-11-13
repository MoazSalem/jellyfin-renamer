Write a program (in Dart, to be run on Windows or Linux) that scans and renames a media library to comply with **Jellyfin’s official naming conventions** for both **TV Shows** and **Movies**, with a built-in **undo system** to restore original names later.

### 🧩 General Features (common to Movies and Shows)
1. Recursively scan the provided root directory for video files.
2. Detect automatically whether each folder represents a Movie or a TV Show (based on structure or user confirmation).
3. Remove or replace illegal filesystem characters (`<`, `>`, `:`, `"`, `/`, `\`, `|`, `?`, `*`).
4. Provide a **dry-run mode** to preview renames before applying.
5. Support a **logging system** that records what was changed.
6. Include full **undo capability**:
   - Before any rename or move operation, save all original file paths and their new paths into a JSON or text log file (e.g. `rename_log.json`):
     ```json
     [
       {
         "original_path": "/media/oldname.mkv",
         "new_path": "/media/Movies/Movie (2022)/Movie (2022).mkv",
         "timestamp": "2025-11-13T12:30:00Z"
       }
     ]
     ```
   - Add a command-line flag `--undo` that reads this log and **reverts** every rename/move to restore the original structure.
   - Handle partial undo safely (e.g., if files were deleted or moved since renaming).
7. Allow configuration through command-line arguments or a YAML/JSON settings file.
8. Include error-handling for name collisions, missing metadata, duplicates, or permission issues.
9. Display a summary report at the end (e.g. “32 renamed, 2 skipped, 1 failed”).

10. When finding metadata for movies/shows, provide interactive CLI prompts for user confirmation and editing:
    - Present multiple potential matches for titles, years, and external IDs
    - Allow users to select from suggested options or manually edit each field
    - Support keyboard navigation and editing for each metadata field
    - Include an option to skip interactive prompts for batch processing

---

### 🎬 For Movies
1. Each movie must be in its own folder named:
   `Movie Name (year) [external id]`
   (the `year` and `[external id]` like `[imdbid-tt1234567]` are optional).
   Reference: https://jellyfin.org/docs/general/server/media/movies/
2. Inside that folder, the video file must have the *same name as the folder* with its extension. Example:

/Movies/
└── Interstellar (2014)/
└── Interstellar (2014).mkv


3. For multiple versions (e.g., 4K, Director’s Cut), append a suffix:
`Movie (2021) [imdbid-tt12345] - 4K.mkv`
or
`Movie (2021) [imdbid-tt12345] - [Director’s Cut].mp4`
4. Detect multi-disc setups (e.g., disc1, disc2) and handle gracefully (warn or merge logically).

---

### 📺 For TV Shows
1. Each show should be in a folder named:
`Series Name (year) [external id]`
Reference: https://jellyfin.org/docs/general/server/media/shows/
2. Inside the series folder, seasons should be in subfolders named:
`Season 01`, `Season 02`, etc. (two-digit padding recommended)
Specials go into `Season 00`.
3. Episode files must include season/episode indicators:
`Series Name (YYYY) SxxExx [Episode Title].ext`
Example:
```

/Shows/
└── Breaking Bad (2008)/
└── Season 01/
└── Breaking Bad (2008) S01E01 Pilot.mkv

```
4. Handle multi-episode files (e.g., `S01E01-E02`) and multi-part episodes (`S01E01-part-1.ext`).
5. Optionally include provider IDs like `[tvdbid-67890]` or `[tmdbid-12345]`.

---

### ⚙️ Optional Enhancements
- Accept metadata (year, IDs, episode titles) from external sources (CSV, JSON, or API).
- Support moving unorganized files into proper folder structures.
- Offer an `--undo-preview` mode to list what will be reverted.
- Provide parallel processing or progress indicators for large libraries.

---

### 🧾 Deliverables
- Full commented source code implementing the above.
- Example config file.
- Example rename log (for undo).
- Usage examples (`--dry-run`, `--apply`, `--undo`).
- Ensure safety: always back up original paths in the undo log before any rename.

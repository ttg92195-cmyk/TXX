# Textpad

A modern, minimal note-taking app built with Flutter. Phase 1 ships full **CRUD** + local persistence. Phase 2 adds **Riverpod state management**, **timeago timestamps**, **real-time search**, and **auto-save**.

## Features

### Phase 1
- **Create** — Write new notes with a title and free-form body.
- **Read** — Browse all saved notes in a clean list.
- **Update** — Tap any note to edit its title or content.
- **Delete** — Remove a note via its card menu, with an Undo snackbar.
- **Persistence** — Every note is stored locally via `shared_preferences`; nothing leaves the device.

### Phase 2
- **Professional timestamps** — `timeago` package renders "3m ago", "1h ago", "2d ago", etc. instead of raw dates.
- **Riverpod state management** — notes live in `notesProvider`, search query in `searchQueryProvider`, derived list in `filteredNotesProvider`. UI just `ref.watch()`-es them.
- **Real-time search** — typing in the search bar instantly filters the list by title or content.
- **Auto-save** — every keystroke schedules a debounced write (800ms after the last edit). The footer cycles through `Unsaved changes` → `Saving...` → `Saved HH:MM`. The user never has to tap Save.

## Tech Stack

- Flutter 3.10+ / Dart 3.0+
- `shared_preferences` — local persistence
- `flutter_riverpod` — state management
- `timeago` — relative timestamps
- Material 3 theming

## Project Structure

```
lib/
├── main.dart                          # App entry + theme + ProviderScope
├── models/
│   └── note.dart                      # Note model with JSON serialization
├── services/
│   └── note_storage.dart              # CRUD on shared_preferences
├── providers/
│   └── notes_provider.dart            # Riverpod providers (notes, search, filtered, actions)
├── screens/
│   ├── home_screen.dart               # Note list, search, delete, clear-all
│   └── note_editor_screen.dart        # Create/Update with auto-save
└── widgets/
    ├── note_card.dart                 # Single note card with timeago label
    └── empty_state.dart               # Friendly empty-state UI
```

## Getting Started

### Prerequisites
Install Flutter ≥ 3.10 from https://docs.flutter.dev/get-started/install.

### Run
```bash
flutter pub get
flutter run
```

### Build a release APK
```bash
flutter build apk --release
```

## CI

A GitHub Actions workflow (`.github/workflows/build-apk.yml`) builds a release APK on every push to `main` and publishes it as a GitHub Release tagged `v1.0.0-build<N>`.

## Roadmap
- **Phase 3** — Isar database for structured local storage, cloud sync, rich text editing.

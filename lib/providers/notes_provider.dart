import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../services/note_storage.dart';

/// Provider for the storage service singleton.
final noteStorageProvider = Provider<NoteStorage>((ref) {
  return NoteStorage();
});

/// A counter that bumps every time the underlying data mutates.
/// Watching this triggers a re-fetch of [notesProvider].
final notesMutationProvider = StateProvider<int>((ref) => 0);

/// Async list of all notes loaded from storage.
final notesProvider = FutureProvider<List<Note>>((ref) async {
  ref.watch(notesMutationProvider);
  final storage = ref.read(noteStorageProvider);
  return storage.getAllNotes();
});

/// Current search query string.
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Derived list of notes filtered by the current search query.
/// Returns the full list when the query is empty.
final filteredNotesProvider = Provider<List<Note>>((ref) {
  final notesAsync = ref.watch(notesProvider);
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  return notesAsync.maybeWhen(
    data: (notes) {
      if (query.isEmpty) return notes;
      return notes
          .where((n) =>
              n.title.toLowerCase().contains(query) ||
              n.content.toLowerCase().contains(query))
          .toList();
    },
    orElse: () => const [],
  );
});

/// Notifier exposing CRUD operations that bump [notesMutationProvider]
/// so consumers of [notesProvider] re-fetch.
class NotesActions {
  NotesActions(this._ref);
  final Ref _ref;

  NoteStorage get _storage => _ref.read(noteStorageProvider);

  void _bump() => _ref.read(notesMutationProvider.notifier).state++;

  Future<Note> createNote({
    required String title,
    required String content,
  }) async {
    final n = await _storage.createNote(title: title, content: content);
    _bump();
    return n;
  }

  Future<Note?> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    final n = await _storage.updateNote(id: id, title: title, content: content);
    _bump();
    return n;
  }

  Future<bool> deleteNote(String id) async {
    final ok = await _storage.deleteNote(id);
    if (ok) _bump();
    return ok;
  }

  Future<void> clearAll() async {
    await _storage.clearAll();
    _bump();
  }
}

final notesActionsProvider = Provider<NotesActions>((ref) {
  return NotesActions(ref);
});

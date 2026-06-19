import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

/// Local persistence layer for [Note] objects.
///
/// Notes are stored as a single JSON-encoded list under the
/// `textpad.notes` key in SharedPreferences. This keeps the
/// dependency footprint small while still providing full CRUD
/// semantics with synchronous read after write.
class NoteStorage {
  static const String _storageKey = 'textpad.notes';

  /// Reads all persisted notes, newest first.
  Future<List<Note>> getAllNotes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final notes = decoded
          .map((e) => Note.fromJson(e as Map<String, dynamic>))
          .toList();
      notes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      return notes;
    } catch (e) {
      // Corrupted data should not crash the app — start fresh.
      return [];
    }
  }

  /// Persists the entire note list. Used internally after every mutation.
  Future<void> _saveAll(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(notes.map((n) => n.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  /// Inserts a new note. Returns the stored note (with generated id).
  Future<Note> createNote({required String title, required String content}) async {
    final notes = await getAllNotes();
    final now = DateTime.now();
    final note = Note(
      id: _generateId(),
      title: title,
      content: content,
      createdAt: now,
      updatedAt: now,
    );
    notes.insert(0, note);
    await _saveAll(notes);
    return note;
  }

  /// Updates an existing note identified by [id].
  /// Returns the updated note, or null if the id was not found.
  Future<Note?> updateNote({
    required String id,
    required String title,
    required String content,
  }) async {
    final notes = await getAllNotes();
    final index = notes.indexWhere((n) => n.id == id);
    if (index == -1) return null;

    final updated = notes[index].copyWith(
      title: title,
      content: content,
      updatedAt: DateTime.now(),
    );
    notes[index] = updated;
    await _saveAll(notes);
    return updated;
  }

  /// Permanently removes the note with the given [id].
  /// Returns true when a note was actually removed.
  Future<bool> deleteNote(String id) async {
    final notes = await getAllNotes();
    final initialLength = notes.length;
    notes.removeWhere((n) => n.id == id);
    await _saveAll(notes);
    return notes.length < initialLength;
  }

  /// Returns a single note by id, or null if it does not exist.
  Future<Note?> getNoteById(String id) async {
    final notes = await getAllNotes();
    for (final n in notes) {
      if (n.id == id) return n;
    }
    return null;
  }

  /// Removes every stored note. Mainly used by the "clear all" action.
  Future<void> clearAll() async {
    await _saveAll([]);
  }

  /// Lightweight unique id generator (timestamp + random suffix).
  String _generateId() {
    final ts = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    final rand = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    return '${ts}_$rand';
  }
}

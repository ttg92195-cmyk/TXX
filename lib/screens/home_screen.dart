import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_storage.dart';
import '../widgets/note_card.dart';
import '../widgets/empty_state.dart';
import 'note_editor_screen.dart';

/// Home screen — lists every saved note and dispatches
/// Create / Update / Delete flows.
class HomeScreen extends StatefulWidget {
  final NoteStorage storage;
  const HomeScreen({super.key, required this.storage});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Note> _notes = [];
  List<Note> _filtered = [];
  bool _isLoading = true;
  bool _isSearching = false;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _loadNotes() async {
    final notes = await widget.storage.getAllNotes();
    if (!mounted) return;
    setState(() {
      _notes = notes;
      _applyFilter();
      _isLoading = false;
    });
  }

  void _applyFilter() {
    if (_query.isEmpty) {
      _filtered = List.of(_notes);
      return;
    }
    final q = _query.toLowerCase();
    _filtered = _notes
        .where((n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _openEditor({Note? note}) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(
          storage: widget.storage,
          existingNote: note,
        ),
      ),
    );
    if (result == true) {
      await _loadNotes();
    }
  }

  Future<void> _confirmDelete(Note note) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text(
          note.title.trim().isEmpty
              ? 'This untitled note will be permanently removed.'
              : '"${note.title}" will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.storage.deleteNote(note.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await widget.storage.createNote(
                title: note.title,
                content: note.content,
              );
              if (!mounted) return;
              await _loadNotes();
            },
          ),
        ),
      );
      await _loadNotes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) {
                  setState(() {
                    _query = v;
                    _applyFilter();
                  });
                },
              )
            : const Text(
                'Textpad',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _query = '';
                  _applyFilter();
                }
              });
            },
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear_all') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Clear all notes?'),
                    content: const Text(
                        'This will permanently delete every saved note.'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel')),
                      FilledButton.tonal(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear all'),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  await widget.storage.clearAll();
                  await _loadNotes();
                }
              }
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: ListTile(
                  leading: Icon(Icons.delete_sweep_outlined,
                      color: Colors.redAccent),
                  title: Text('Clear all notes',
                      style: TextStyle(color: Colors.redAccent)),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _notes.isEmpty
              ? EmptyState(
                  title: 'No notes yet',
                  subtitle:
                      'Tap the + button below to write your first note.\n'
                      'Notes are saved automatically on your phone.',
                  onAction: () => _openEditor(),
                  actionLabel: 'Create note',
                )
              : _filtered.isEmpty
                  ? EmptyState(
                      title: 'No matches',
                      subtitle: 'No notes contain "$_query".',
                      icon: Icons.search_off,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadNotes,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            16, 8, 16, 96),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final note = _filtered[index];
                          return NoteCard(
                            note: note,
                            onTap: () => _openEditor(note: note),
                            onEdit: () => _openEditor(note: note),
                            onDelete: () => _confirmDelete(note),
                          );
                        },
                      ),
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }
}

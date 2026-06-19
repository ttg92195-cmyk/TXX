import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/empty_state.dart';
import 'note_editor_screen.dart';

/// Home screen — lists every saved note and dispatches
/// Create / Update / Delete flows.
///
/// Phase 2: now uses Riverpod for state. The note list and the
/// search query live in providers; this widget just renders them.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _enterSearch() {
    setState(() => _isSearching = true);
  }

  void _exitSearch() {
    setState(() => _isSearching = false);
    _searchController.clear();
    ref.read(searchQueryProvider.notifier).state = '';
  }

  Future<void> _openEditor({Note? note}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => NoteEditorScreen(existingNote: note),
      ),
    );
    // The editor uses Riverpod actions that bump notesMutationProvider,
    // so the list re-fetches automatically — no manual reload needed.
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
      final actions = ref.read(notesActionsProvider);
      await actions.deleteNote(note.id);
      if (!mounted) return;
      // Undo: re-create the note with the same content.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Note deleted'),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () async {
              await actions.createNote(
                title: note.title,
                content: note.content,
              );
            },
          ),
        ),
      );
    }
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notes?'),
        content: const Text('This will permanently delete every saved note.'),
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
            child: const Text('Clear all'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(notesActionsProvider).clearAll();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Watch the derived filtered list — rebuilds when notes or query change.
    final filtered = ref.watch(filteredNotesProvider);
    // Watch the async source so we know whether the user has any notes at all.
    final notesAsync = ref.watch(notesProvider);
    final hasAnyNote = notesAsync.maybeWhen(
      data: (n) => n.isNotEmpty,
      orElse: () => false,
    );
    final isLoading = notesAsync.isLoading && !notesAsync.hasValue;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search notes...',
                  border: InputBorder.none,
                  filled: false,
                ),
                onChanged: (v) {
                  ref.read(searchQueryProvider.notifier).state = v;
                },
              )
            : const Text(
                'Textpad',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _isSearching ? _exitSearch : _enterSearch,
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'clear_all') _confirmClearAll();
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
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          // Empty-state ternary — explicit per Phase 2 brief.
          : !hasAnyNote
              ? EmptyState(
                  title: 'No notes yet',
                  subtitle:
                      'Tap the + button below to write your first note.\n'
                      'Notes are saved automatically on your phone.',
                  onAction: () => _openEditor(),
                  actionLabel: 'Create note',
                )
              : filtered.isEmpty
                  ? EmptyState(
                      title: 'No matches',
                      subtitle:
                          'No notes contain "${_searchController.text}".',
                      icon: Icons.search_off,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final note = filtered[index];
                        return NoteCard(
                          note: note,
                          onTap: () => _openEditor(note: note),
                          onEdit: () => _openEditor(note: note),
                          onDelete: () => _confirmDelete(note),
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
    );
  }
}

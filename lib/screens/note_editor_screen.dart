import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/note.dart';
import '../providers/notes_provider.dart';

/// Single screen used for both creating new notes and editing existing ones.
///
/// Phase 2 — Auto-save:
///   Every keystroke schedules a debounced write (800ms after the last edit).
///   The footer status cycles through:
///     "Unsaved changes" -> "Saving..." -> "Saved <time>"
///   The user never has to tap Save, though the Save button still works
///   as an explicit "save now" shortcut.
class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? existingNote;

  const NoteEditorScreen({
    super.key,
    this.existingNote,
  });

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

/// Internal auto-save status shown in the footer.
enum _SaveStatus { clean, dirty, saving, saved }

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocus;

  Timer? _debounce;
  bool _isSaving = false;
  _SaveStatus _status = _SaveStatus.clean;
  DateTime? _lastSavedAt;
  String? _activeNoteId; // null = creating new; non-null = editing existing

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?.content ?? '');
    _contentFocus = FocusNode();
    _activeNoteId = widget.existingNote?.id;

    _titleController.addListener(_onChanged);
    _contentController.addListener(_onChanged);
  }

  void _onChanged() {
    if (_status != _SaveStatus.dirty && _status != _SaveStatus.saving) {
      setState(() => _status = _SaveStatus.dirty);
    } else if (_status == _SaveStatus.saved) {
      setState(() => _status = _SaveStatus.dirty);
    }
    // Reset the debounce timer on every keystroke — Option B style.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 800), _autoSave);
  }

  Future<void> _autoSave() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    // Don't save an empty note — wait for content.
    if (title.isEmpty && content.isEmpty) return;

    if (!mounted) return;
    setState(() {
      _isSaving = true;
      _status = _SaveStatus.saving;
    });

    try {
      final actions = ref.read(notesActionsProvider);
      if (_activeNoteId == null) {
        // Creating a brand-new note via auto-save.
        final created = await actions.createNote(title: title, content: content);
        _activeNoteId = created.id;
      } else {
        // Updating an existing note.
        await actions.updateNote(
          id: _activeNoteId!,
          title: title,
          content: content,
        );
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = _SaveStatus.saved;
        _lastSavedAt = DateTime.now();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _status = _SaveStatus.dirty; // keep "unsaved" so user knows to retry
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Auto-save failed: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    await _autoSave();
  }

  Future<bool> _onWillPop() async {
    // If there are pending changes, flush them before leaving.
    if (_status == _SaveStatus.dirty || _status == _SaveStatus.saving) {
      await _saveNow();
    }
    return true;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit note' : 'New note',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.check),
              tooltip: 'Save now',
              onPressed: _isSaving ? null : _saveNow,
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.sentences,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Note title',
                    border: InputBorder.none,
                    filled: false,
                  ),
                  onSubmitted: (_) => _contentFocus.requestFocus(),
                ),
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: TextField(
                    controller: _contentController,
                    focusNode: _contentFocus,
                    maxLines: null,
                    expands: true,
                    textAlignVertical: TextAlignVertical.top,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                    decoration: const InputDecoration(
                      hintText: 'Start writing your thoughts...',
                      border: InputBorder.none,
                      filled: false,
                    ),
                  ),
                ),
              ),
              _AutoSaveBar(
                status: _status,
                lastSavedAt: _lastSavedAt,
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isSaving ? null : _saveNow,
          child: _isSaving
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save),
        ),
      ),
    );
  }
}

/// Footer bar that surfaces the current auto-save state to the user.
class _AutoSaveBar extends StatelessWidget {
  final _SaveStatus status;
  final DateTime? lastSavedAt;

  const _AutoSaveBar({required this.status, this.lastSavedAt});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (label, color, icon) = switch (status) {
      _SaveStatus.clean => (
          'All changes saved',
          theme.colorScheme.outline,
          Icons.cloud_done_outlined,
        ),
      _SaveStatus.dirty => (
          'Unsaved changes',
          theme.colorScheme.onSurfaceVariant,
          Icons.edit_outlined,
        ),
      _SaveStatus.saving => (
          'Saving...',
          theme.colorScheme.primary,
          Icons.sync,
        ),
      _SaveStatus.saved => (
          'Saved ${_shortTime(lastSavedAt)}',
          theme.colorScheme.outline,
          Icons.check_circle_outline,
        ),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  String _shortTime(DateTime? dt) {
    if (dt == null) return '';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

import 'package:flutter/material.dart';
import '../models/note.dart';
import '../services/note_storage.dart';

/// Single screen used for both creating new notes and editing existing ones.
///
/// When [existingNote] is null, the screen operates in "create" mode.
/// When provided, it operates in "edit" mode and pre-populates the fields.
class NoteEditorScreen extends StatefulWidget {
  final NoteStorage storage;
  final Note? existingNote;

  const NoteEditorScreen({
    super.key,
    required this.storage,
    this.existingNote,
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final FocusNode _contentFocus;
  bool _isSaving = false;
  bool _hasChanges = false;
  bool _autoSaved = false;

  bool get _isEditing => widget.existingNote != null;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.existingNote?.title ?? '');
    _contentController =
        TextEditingController(text: widget.existingNote?.content ?? '');
    _contentFocus = FocusNode();

    _titleController.addListener(_markChanged);
    _contentController.addListener(_markChanged);
  }

  void _markChanged() {
    if (!_hasChanges) {
      setState(() => _hasChanges = true);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _contentFocus.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (!_hasChanges) return true;
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) return true;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text(
            'You have unsaved changes. Do you want to save them before leaving?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (action == 'cancel') return false;
    if (action == 'save') {
      await _saveNote();
    }
    return true;
  }

  Future<void> _saveNote() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot save an empty note'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await widget.storage.updateNote(
          id: widget.existingNote!.id,
          title: title,
          content: content,
        );
      } else {
        await widget.storage.createNote(title: title, content: content);
      }
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _hasChanges = false;
        _autoSaved = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEditing ? 'Note updated' : 'Note created'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 1),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: !_hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _onWillPop();
        if (shouldPop && mounted) {
          Navigator.of(context).pop(_autoSaved);
        }
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
              tooltip: 'Save',
              onPressed: _isSaving ? null : _saveNote,
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
              if (_hasChanges)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  color: theme.colorScheme.surfaceContainerHighest
                      .withOpacity(0.4),
                  child: Text(
                    'Unsaved changes',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _isSaving ? null : _saveNote,
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

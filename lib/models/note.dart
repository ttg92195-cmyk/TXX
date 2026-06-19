import 'package:flutter/material.dart';

/// Represents a single note in the Textpad app.
///
/// Each note has a unique [id], a [title], the [content] body,
/// and timestamps for [createdAt] and [updatedAt]. The model is
/// serializable to/from JSON so it can be persisted via
/// SharedPreferences.
@immutable
class Note {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Creates a copy of this note with optionally overridden fields.
  /// When any text field is changed, [updatedAt] is refreshed.
  Note copyWith({
    String? title,
    String? content,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  /// Serializes the note into a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Reconstructs a [Note] from a JSON map produced by [toJson].
  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// A short preview of the content used in list cards.
  String get preview {
    final stripped = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (stripped.length <= 80) return stripped;
    return '${stripped.substring(0, 80)}…';
  }

  /// Returns true when the note has no meaningful content.
  bool get isEmpty => title.trim().isEmpty && content.trim().isEmpty;
}

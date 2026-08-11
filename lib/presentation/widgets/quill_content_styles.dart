import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;

/// Builds the shared rich-text styles used by the editor, preview, and reader.
///
/// Keeping these styles in one place prevents the three rendering surfaces from
/// drifting apart when typography or spacing is adjusted.
quill.DefaultStyles buildQuillContentStyles(ThemeData theme) {
  final isDark = theme.brightness == Brightness.dark;

  return quill.DefaultStyles(
    paragraph: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(8, 8),
      quill.VerticalSpacing.zero,
      null,
    ),
    h1: quill.DefaultTextBlockStyle(
      theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 28,
          ) ??
          const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(16, 8),
      quill.VerticalSpacing.zero,
      null,
    ),
    h2: quill.DefaultTextBlockStyle(
      theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: 22,
          ) ??
          const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(12, 6),
      quill.VerticalSpacing.zero,
      null,
    ),
    h3: quill.DefaultTextBlockStyle(
      theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ) ??
          const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(10, 4),
      quill.VerticalSpacing.zero,
      null,
    ),
    lists: quill.DefaultListBlockStyle(
      theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(4, 4),
      quill.VerticalSpacing.zero,
      null,
      null,
    ),
    quote: quill.DefaultTextBlockStyle(
      theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.7),
          ) ??
          const TextStyle(fontSize: 14),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(8, 8),
      quill.VerticalSpacing.zero,
      null,
    ),
    code: quill.DefaultTextBlockStyle(
      TextStyle(
        fontFamily: 'monospace',
        fontSize: 14,
        color: isDark ? Colors.green[300] : Colors.green[800],
      ),
      quill.HorizontalSpacing.zero,
      const quill.VerticalSpacing(8, 8),
      quill.VerticalSpacing.zero,
      BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    sizeSmall: const TextStyle(fontSize: 12),
    sizeLarge: const TextStyle(fontSize: 18),
    sizeHuge: const TextStyle(fontSize: 24),
    italic: const TextStyle(
      fontStyle: FontStyle.italic,
      fontFamily: 'Consolas',
      fontFamilyFallback: [
        'Courier New',
        'Menlo',
        'Monaco',
        'Droid Sans Mono',
        'monospace',
      ],
      height: 1.2,
    ),
  );
}

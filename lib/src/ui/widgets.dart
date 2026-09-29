import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../network_entry.dart';

TextStyle monoStyle(BuildContext context) => TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: const ['Menlo', 'Courier', 'Roboto Mono'],
  fontSize: 12.5,
  height: 1.45,
  color: Theme.of(context).colorScheme.onSurface,
);

/// Status code chip: grey while pending, green 2xx/3xx, amber 4xx/5xx, red on
/// a network error.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.entry});

  final NetworkEntry entry;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (label, color) = switch (entry) {
      NetworkEntry(isPending: true) => ('…', Colors.blueGrey),
      NetworkEntry(isSuccess: true) => ('${entry.statusCode}', Colors.green),
      NetworkEntry(:final statusCode?) => ('$statusCode', Colors.orange),
      _ => ('ERR', Colors.red),
    };
    return Container(
      width: 48,
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.25 : 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: monoStyle(context).copyWith(
          color: dark ? color.shade200 : color.shade800,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Titled monospace block with a copy button.
class CodeSection extends StatelessWidget {
  const CodeSection({super.key, required this.title, required this.text, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.labelLarge),
                    if (subtitle != null) Text(subtitle!, style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
              ?trailing,
              if (text.isNotEmpty) CopyButton(text: text, what: title),
            ],
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(text.isEmpty ? '—' : text, style: monoStyle(context)),
          ),
        ],
      ),
    );
  }
}

class CopyButton extends StatelessWidget {
  const CopyButton({super.key, required this.text, required this.what});

  final String text;
  final String what;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Copy $what',
    visualDensity: VisualDensity.compact,
    iconSize: 18,
    onPressed: () async {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) {
        ScaffoldMessenger.maybeOf(context)
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text('Copied $what')));
      }
    },
    icon: const Icon(Icons.copy_rounded),
  );
}

String formatHeaders(Map<String, Object?> headers) => headers.entries
    .map((e) => '${e.key}: ${e.value is List ? (e.value as List).join(', ') : e.value}')
    .join('\n');

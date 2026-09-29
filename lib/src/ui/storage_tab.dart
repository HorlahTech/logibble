import 'package:flutter/material.dart';

import '../debug_storage.dart';
import '../network_entry.dart';
import 'widgets.dart';

/// One section per [DebugStorage], reloaded after every change.
class StorageTab extends StatefulWidget {
  const StorageTab({super.key, required this.storage});

  final List<DebugStorage> storage;

  @override
  State<StorageTab> createState() => _StorageTabState();
}

class _StorageTabState extends State<StorageTab> {
  late Future<List<List<DebugStorageEntry>>> _data = _read();

  Future<List<List<DebugStorageEntry>>> _read() => Future.wait([for (final s in widget.storage) s.read()]);

  Future<void> _reload() {
    final next = _read();
    setState(() {
      _data = next;
    });
    return next.then((_) {}, onError: (_) {});
  }

  Future<void> _run(Future<void> Function() action) async {
    await action();
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not read storage:\n${snapshot.error}', textAlign: TextAlign.center));
        }
        final sections = snapshot.data;
        if (sections == null) return const Center(child: CircularProgressIndicator());
        final textTheme = Theme.of(context).textTheme;

        return RefreshIndicator(
          onRefresh: _reload,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              for (final (i, source) in widget.storage.indexed) ...[
                Row(
                  children: [
                    Expanded(child: Text('${source.name} (${sections[i].length})', style: textTheme.titleSmall)),
                    if (source.clear case final clear?)
                      TextButton(
                        onPressed: sections[i].isEmpty ? null : () => _run(clear),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                if (sections[i].isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text('Nothing stored.', style: textTheme.bodySmall),
                  ),
                for (final entry in sections[i])
                  CodeSection(
                    title: entry.key,
                    subtitle: entry.note,
                    text: _preview(entry.value),
                    trailing: switch (source.delete) {
                      final delete? => IconButton(
                        tooltip: 'Delete ${entry.key}',
                        visualDensity: VisualDensity.compact,
                        iconSize: 18,
                        onPressed: () => _run(() => delete(entry.key)),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                      null => null,
                    },
                  ),
                const SizedBox(height: 8),
              ],
            ],
          ),
        );
      },
    );
  }

  static String _preview(Object? value) {
    final text = prettyBody(value);
    return text.length > 4000 ? '${text.substring(0, 4000)}\n…' : text;
  }
}

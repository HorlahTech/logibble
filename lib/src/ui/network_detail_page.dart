import 'package:flutter/material.dart';

import '../logibble.dart';
import '../network_entry.dart';
import 'widgets.dart';

/// Everything about one request: overview, headers and bodies.
class NetworkDetailPage extends StatelessWidget {
  const NetworkDetailPage({super.key, required this.logibble, required this.id});

  final Logibble logibble;
  final int id;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: logibble,
      builder: (context, _) {
        final entry = logibble.entry(id);
        if (entry == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This entry was cleared.')),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                StatusBadge(entry: entry),
                const SizedBox(width: 12),
                Expanded(child: Text(entry.uri.path, overflow: TextOverflow.ellipsis)),
              ],
            ),
            actions: [CopyButton(text: entry.toCurl(), what: 'cURL')],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              CodeSection(title: 'Overview', text: _summary(entry)),
              CodeSection(title: 'Request headers', text: formatHeaders(entry.requestHeaders)),
              CodeSection(title: 'Request body', text: prettyBody(entry.requestBody)),
              CodeSection(title: 'Response headers', text: formatHeaders(entry.responseHeaders)),
              CodeSection(title: 'Response body', text: prettyBody(entry.responseBody)),
            ],
          ),
        );
      },
    );
  }

  static String _summary(NetworkEntry entry) => [
    '${entry.method} ${entry.uri}',
    'Status: ${entry.isPending ? 'pending' : entry.statusCode ?? '—'}${entry.fromCache ? ' (from cache)' : ''}',
    if (entry.duration != null) 'Time: ${entry.duration!.inMilliseconds} ms',
    'Started: ${entry.startedAt.toIso8601String()}',
    if (entry.error != null) 'Error: ${entry.error}',
  ].join('\n');
}

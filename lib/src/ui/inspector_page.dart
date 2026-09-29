import 'package:flutter/material.dart';

import '../logibble.dart';
import '../network_entry.dart';
import 'network_detail_page.dart';
import 'storage_tab.dart';
import 'widgets.dart';

/// The inspector screen: a Network tab, plus a Storage tab when the bubble has
/// storage sections. [LogibbleOverlay] pushes it; you can also push it
/// yourself (e.g. from a settings screen or a shake gesture).
class LogibbleInspectorPage extends StatelessWidget {
  /// Creates the inspector for [logibble], or [Logibble.instance] when omitted.
  LogibbleInspectorPage({super.key, Logibble? logibble}) : logibble = logibble ?? Logibble.instance;

  /// Source of network entries and storage sections.
  final Logibble logibble;

  @override
  Widget build(BuildContext context) {
    final hasStorage = logibble.storage.isNotEmpty;
    final network = _NetworkTab(logibble: logibble);
    return DefaultTabController(
      length: hasStorage ? 2 : 1,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Debug'),
          bottom: hasStorage
              ? const TabBar(
                  tabs: [
                    Tab(text: 'Network'),
                    Tab(text: 'Storage'),
                  ],
                )
              : null,
        ),
        body: hasStorage ? TabBarView(children: [network, StorageTab(storage: logibble.storage)]) : network,
      ),
    );
  }
}

class _NetworkTab extends StatefulWidget {
  const _NetworkTab({required this.logibble});

  final Logibble logibble;

  @override
  State<_NetworkTab> createState() => _NetworkTabState();
}

class _NetworkTabState extends State<_NetworkTab> {
  var _query = '';

  bool _matches(NetworkEntry entry) =>
      '${entry.method} ${entry.uri} ${entry.statusCode ?? ''}'.toLowerCase().contains(_query);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.logibble,
      builder: (context, _) {
        final all = widget.logibble.entries;
        final entries = _query.isEmpty ? all : all.where(_matches).toList();
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      autocorrect: false,
                      decoration: const InputDecoration(
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Filter by method, path or status',
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Clear log',
                    onPressed: all.isEmpty ? null : widget.logibble.clear,
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
                ],
              ),
            ),
            Expanded(
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        all.isEmpty ? 'No requests yet.' : 'Nothing matches.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    )
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (context, i) => _EntryTile(logibble: widget.logibble, entry: entries[i]),
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.logibble, required this.entry});

  final Logibble logibble;
  final NetworkEntry entry;

  @override
  Widget build(BuildContext context) {
    final time = TimeOfDay.fromDateTime(entry.startedAt).format(context);
    final meta = [
      time,
      if (entry.duration != null) '${entry.duration!.inMilliseconds} ms',
      if (entry.fromCache) 'cache',
    ].join(' · ');

    return ListTile(
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute<void>(builder: (_) => NetworkDetailPage(logibble: logibble, id: entry.id))),
      leading: StatusBadge(entry: entry),
      title: Text(
        '${entry.method} ${entry.uri.path}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: monoStyle(context).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      subtitle: Text('${entry.uri.host} · $meta'),
    );
  }
}

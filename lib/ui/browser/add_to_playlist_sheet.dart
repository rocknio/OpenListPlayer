/// "添加到播单"底部弹层：选已有播单或新建。
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/app_database.dart';

/// 返回 true 表示已添加
Future<bool> showAddToPlaylistSheet(
    BuildContext context, AppDatabase db, List<QueueItem> items) async {
  if (items.isEmpty) return false;
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddToPlaylistSheet(db: db, items: items),
  );
  return result == 'added';
}

class _AddToPlaylistSheet extends StatefulWidget {
  const _AddToPlaylistSheet({required this.db, required this.items});
  final AppDatabase db;
  final List<QueueItem> items;

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  final _newNameCtrl = TextEditingController();

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addTo(int playlistId) async {
    await widget.db.addItemsToPlaylist(playlistId, widget.items);
    if (mounted) Navigator.of(context).pop('added');
  }

  Future<void> _createAndAdd() async {
    final name = _newNameCtrl.text.trim();
    if (name.isEmpty) return;
    final id = await widget.db.createPlaylist(name);
    await _addTo(id);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('添加 ${widget.items.length} 个文件到播单',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Flexible(
              child: StreamBuilder<List<Playlist>>(
                stream: widget.db.playlistsStream(),
                builder: (context, snap) {
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('还没有播单，创建一个吧'),
                    );
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final p in list)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.playlist_play),
                          title: Text(p.name),
                          onTap: () => _addTo(p.id),
                        ),
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _newNameCtrl,
                    decoration: const InputDecoration(
                      labelText: '新播单名称',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _createAndAdd(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('新建并添加'),
                  onPressed: _createAndAdd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

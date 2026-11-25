/// "添加到播单"底部弹层：选已有播单或新建。
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../data/app_database.dart';

/// 返回实际新增的条目数；用户取消返回 null。
Future<int?> showAddToPlaylistSheet(
    BuildContext context, AppDatabase db, List<QueueItem> items) async {
  if (items.isEmpty) return null;
  return showModalBottomSheet<int>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _AddToPlaylistSheet(db: db, items: items),
  );
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
  bool _submitting = false;

  @override
  void dispose() {
    _newNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addTo(int playlistId) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final count = await widget.db.addItemsToPlaylist(playlistId, widget.items);
      if (mounted) Navigator.of(context).pop(count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('添加失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createAndAdd() async {
    if (_submitting) return;
    final trimmed = _newNameCtrl.text.trim();
    if (trimmed.isEmpty) return;
    final name = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    setState(() => _submitting = true);
    try {
      final id = await widget.db.createPlaylist(name);
      final count = await widget.db.addItemsToPlaylist(id, widget.items);
      if (mounted) Navigator.of(context).pop(count);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('创建失败: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 16 + bottomInset),
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
                          enabled: !_submitting,
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
                    enabled: !_submitting,
                    maxLength: 100,
                    decoration: const InputDecoration(
                      labelText: '新播单名称',
                      counterText: '',
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
                  onPressed: _submitting ? null : _createAndAdd,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

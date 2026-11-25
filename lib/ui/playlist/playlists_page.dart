/// 播单列表页：新建、进入详情、重命名、删除。
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/app_database.dart';
import '../../providers.dart';
import 'current_queue_page.dart';
import 'playlist_detail_page.dart';

class PlaylistsPage extends ConsumerStatefulWidget {
  const PlaylistsPage({super.key});

  @override
  ConsumerState<PlaylistsPage> createState() => _PlaylistsPageState();
}

class _PlaylistsPageState extends ConsumerState<PlaylistsPage> {
  AppDatabase? _cachedDb;
  Stream<List<Playlist>>? _playlistsStream;

  Stream<List<Playlist>> _streamFor(AppDatabase db) {
    if (!identical(_cachedDb, db) || _playlistsStream == null) {
      _cachedDb = db;
      _playlistsStream = db.playlistsStream();
    }
    return _playlistsStream!;
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('播单')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新建播单'),
        onPressed: () => _create(context, db),
      ),
      body: Column(
        children: [
          const CurrentPlaylistTile(),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<Playlist>>(
              stream: _streamFor(db),
              builder: (context, snap) {
                final list = snap.data ?? [];
                if (list.isEmpty) {
                  return const Center(
                    child: Text('还没有播单\n点右下角新建，进入播单后可添加文件', textAlign: TextAlign.center),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 88),
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final p = list[i];
                    return ListTile(
                      leading: const Icon(Icons.playlist_play),
                      title: Text(p.name),
                      subtitle: Text(_fmtDate(p.createdAt)),
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) {
                          if (action == 'rename') _rename(context, db, p);
                          if (action == 'delete') _delete(context, db, p);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'rename', child: Text('重命名')),
                          PopupMenuItem(value: 'delete', child: Text('删除播单')),
                        ],
                      ),
                      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => PlaylistDetailPage(playlistId: p.id, playlistName: p.name),
                      )),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} 创建';

  Future<void> _create(BuildContext context, AppDatabase db) async {
    final name = await _promptName(context, title: '新建播单');
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final safeName = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    await db.createPlaylist(safeName);
  }

  Future<void> _rename(BuildContext context, AppDatabase db, Playlist p) async {
    final name = await _promptName(context, title: '重命名播单', initial: p.name);
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty) return;
    final safeName = trimmed.length > 100 ? trimmed.substring(0, 100) : trimmed;
    await db.renamePlaylist(p.id, safeName);
  }

  Future<void> _delete(BuildContext context, AppDatabase db, Playlist p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除播单'),
        content: Text('确定删除播单"${p.name}"吗？其中的文件不会被删除。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
    if (ok == true) await db.deletePlaylist(p.id);
  }

  Future<String?> _promptName(BuildContext context,
      {required String title, String? initial}) {
    return showDialog<String>(
      context: context,
      builder: (context) => _PlaylistNameDialog(title: title, initial: initial),
    );
  }
}

class _PlaylistNameDialog extends StatefulWidget {
  const _PlaylistNameDialog({required this.title, this.initial});

  final String title;
  final String? initial;

  @override
  State<_PlaylistNameDialog> createState() => _PlaylistNameDialogState();
}

class _PlaylistNameDialogState extends State<_PlaylistNameDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initial ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: 100,
        decoration: const InputDecoration(hintText: '播单名称', counterText: ''),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(context, _ctrl.text), child: const Text('确定')),
      ],
    );
  }
}

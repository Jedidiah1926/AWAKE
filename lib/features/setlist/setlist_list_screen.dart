import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../models/setlist.dart';
import 'format.dart';
import 'setlist_detail_screen.dart';
import 'setlist_editor_screen.dart';

/// 최근 콘티 목록.
class SetlistListScreen extends StatelessWidget {
  const SetlistListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scope = TeamScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('콘티')),
      floatingActionButton: scope.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SetlistEditorScreen(data: scope.data),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('새 콘티'),
            )
          : null,
      body: StreamView<List<Setlist>>(
        create: scope.data.watchSetlists,
        id: scope.data.teamId,
        isEmpty: (list) => list.isEmpty,
        empty: EmptyMessage(
          icon: Icons.queue_music,
          message: scope.canEdit
              ? '아직 콘티가 없습니다.\n"새 콘티"로 이번 예배 콘티를 만들어 보세요.'
              : '아직 콘티가 없습니다.',
        ),
        builder: (context, setlists) => ListView.builder(
          padding: const EdgeInsets.only(bottom: 88),
          itemCount: setlists.length,
          itemBuilder: (context, i) {
            final s = setlists[i];
            return ListTile(
              leading: const Icon(Icons.event_note),
              title: Text(s.title),
              subtitle: Text(
                '${formatDate(s.date)} · ${s.items.length}곡'
                '${s.items.isEmpty ? '' : ' · ${s.items.map((e) => e.key).join(' ')}'}',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SetlistDetailScreen(setlistId: s.id),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

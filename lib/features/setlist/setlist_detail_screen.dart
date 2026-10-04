import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../core/music/progression.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import '../song/song_chart_screen.dart';
import 'format.dart';
import 'setlist_editor_screen.dart';

/// 콘티 보기. 인도자가 바꾸면 실시간으로 반영된다.
class SetlistDetailScreen extends StatelessWidget {
  const SetlistDetailScreen({super.key, required this.setlistId});

  final String setlistId;

  @override
  Widget build(BuildContext context) {
    final scope = TeamScope.of(context);
    return StreamView<Setlist?>(
      create: () => scope.data.watchSetlist(setlistId),
      id: setlistId,
      builder: (context, setlist) {
        if (setlist == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyMessage(
              icon: Icons.delete_outline,
              message: '삭제된 콘티입니다.',
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text(setlist.title),
            actions: [
              if (scope.canEdit)
                IconButton(
                  tooltip: '편집',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => SetlistEditorScreen(
                        data: scope.data,
                        setlist: setlist,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          body: StreamView<List<Song>>(
            create: scope.data.watchSongs,
            id: scope.data.teamId,
            builder: (context, songs) {
              final byId = {for (final s in songs) s.id: s};
              return FormWidth(
                maxWidth: 800,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      formatDate(setlist.date),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (setlist.memo?.isNotEmpty ?? false)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(setlist.memo!),
                      ),
                    const SizedBox(height: 12),
                    if (setlist.items.isEmpty)
                      const EmptyMessage(
                        icon: Icons.music_off,
                        message: '곡이 없습니다.',
                      ),
                    for (final (i, item) in setlist.items.indexed)
                      _ItemCard(index: i, item: item, song: byId[item.songId]),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({required this.index, required this.item, this.song});

  final int index;
  final SetlistItem item;

  /// 곡이 삭제됐으면 null.
  final Song? song;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chordStyle = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    final song = this.song;
    final intro = song == null ? item.intro ?? [] : item.introFor(song);
    final outro = song == null ? item.outro ?? [] : item.outroFor(song);

    return Card(
      child: ListTile(
        leading: CircleAvatar(child: Text('${index + 1}')),
        title: Text(item.title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (intro.isNotEmpty)
              Text('Intro ${formatProgression(intro)}', style: chordStyle),
            if (outro.isNotEmpty)
              Text('Outro ${formatProgression(outro)}', style: chordStyle),
            if (item.memo?.isNotEmpty ?? false) Text(item.memo!),
            if (song == null)
              Text(
                '곡 목록에서 삭제된 곡입니다.',
                style: TextStyle(color: theme.colorScheme.error),
              ),
          ],
        ),
        trailing: Chip(label: Text(item.key)),
        isThreeLine: intro.isNotEmpty && outro.isNotEmpty,
        onTap: song == null
            ? null
            : () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SongChartScreen(
                    song: song,
                    initialKey: item.key,
                    intro: item.intro,
                    outro: item.outro,
                    memo: item.memo,
                  ),
                ),
              ),
      ),
    );
  }
}

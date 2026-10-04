import 'package:flutter/material.dart';

import '../../app/scope.dart';
import '../../app/widgets.dart';
import '../../models/song.dart';
import 'song_chart_screen.dart';
import 'song_editor_screen.dart';

/// 팀 곡 목록. 검색, 추가, 보기.
class SongListScreen extends StatefulWidget {
  const SongListScreen({super.key});

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  var _query = '';

  void _open(BuildContext context, Song song) {
    final scope = TeamScope.of(context);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongChartScreen(
          song: song,
          actions: [
            if (scope.canEdit)
              Builder(
                builder: (context) => IconButton(
                  tooltip: '편집',
                  icon: const Icon(Icons.edit),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          SongEditorScreen(data: scope.data, song: song),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = TeamScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('곡'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: SearchBar(
              hintText: '제목, 아티스트 검색',
              leading: const Icon(Icons.search),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      floatingActionButton: scope.canEdit
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => SongEditorScreen(data: scope.data),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('곡 추가'),
            )
          : null,
      body: StreamView<List<Song>>(
        create: scope.data.watchSongs,
        id: scope.data.teamId,
        isEmpty: (songs) => songs.isEmpty,
        empty: EmptyMessage(
          icon: Icons.library_music,
          message: scope.canEdit
              ? '등록된 곡이 없습니다.\n"곡 추가"로 첫 곡을 등록하세요.'
              : '등록된 곡이 없습니다.',
        ),
        builder: (context, songs) {
          final filtered = _query.isEmpty
              ? songs
              : songs
                    .where(
                      (s) =>
                          s.title.toLowerCase().contains(_query) ||
                          (s.artist?.toLowerCase().contains(_query) ?? false),
                    )
                    .toList();
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: filtered.length,
            itemBuilder: (context, i) {
              final song = filtered[i];
              return ListTile(
                leading: CircleAvatar(child: Text(song.originalKey)),
                title: Text(song.title),
                subtitle: song.artist == null ? null : Text(song.artist!),
                onTap: () => _open(context, song),
              );
            },
          );
        },
      ),
    );
  }
}

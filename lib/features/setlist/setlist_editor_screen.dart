import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../core/music/music_key.dart';
import '../../core/music/progression.dart';
import '../../core/music/transposer.dart';
import '../../data/backend.dart';
import '../../models/setlist.dart';
import '../../models/song.dart';
import 'format.dart';

/// 콘티 만들기/편집. 곡 추가, 순서 바꾸기(드래그), 곡별 조·인트로·아웃트로·메모.
class SetlistEditorScreen extends StatefulWidget {
  const SetlistEditorScreen({
    super.key,
    required this.data,
    this.setlist,
    this.now,
  });

  final TeamData data;

  /// null이면 새 콘티.
  final Setlist? setlist;

  /// 테스트용 현재 시각.
  final DateTime? now;

  @override
  State<SetlistEditorScreen> createState() => _SetlistEditorScreenState();
}

class _SetlistEditorScreenState extends State<SetlistEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(
    text: widget.setlist?.title ?? '주일 예배',
  );
  late final _memo = TextEditingController(text: widget.setlist?.memo);
  late DateTime _date =
      widget.setlist?.date ?? nextSunday(widget.now ?? DateTime.now());
  late final List<SetlistItem> _items = [...?widget.setlist?.items];

  /// 순서 바꾸기 애니메이션용 고유 키 (같은 곡을 두 번 넣을 수도 있어서 songId는 안 됨).
  late final List<int> _rowIds = [for (var i = 0; i < _items.length; i++) i];
  late int _nextRowId = _items.length;
  late final Stream<List<Song>> _songs = widget.data.watchSongs();
  List<Song> _songList = const [];
  var _busy = false;

  @override
  void dispose() {
    _title.dispose();
    _memo.dispose();
    super.dispose();
  }

  Song? _song(String id) => _songList.where((s) => s.id == id).firstOrNull;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _addSong() async {
    final song = await showDialog<Song>(
      context: context,
      builder: (_) => _SongPicker(songs: _songList),
    );
    if (song != null) {
      setState(() {
        _items.add(SetlistItem.fromSong(song));
        _rowIds.add(_nextRowId++);
      });
    }
  }

  Future<void> _editItem(int index) async {
    final item = _items[index];
    final updated = await showDialog<SetlistItem>(
      context: context,
      builder: (_) => _ItemDialog(item: item, song: _song(item.songId)),
    );
    if (updated != null) setState(() => _items[index] = updated);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final memo = _memo.text.trim();
    final setlist = Setlist(
      id: widget.setlist?.id ?? widget.data.newSetlistId(),
      title: _title.text.trim(),
      date: _date,
      memo: memo.isEmpty ? null : memo,
      items: List.of(_items),
    );
    setState(() => _busy = true);
    final ok = await runWithFeedback(
      context,
      () => widget.data.saveSetlist(setlist),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: '콘티 삭제',
      message: '"${widget.setlist!.title}" 콘티를 삭제할까요?',
    );
    if (!ok || !mounted) return;
    final done = await runWithFeedback(
      context,
      () => widget.data.deleteSetlist(widget.setlist!.id),
    );
    // 콘티 보기 화면도 함께 닫고 목록으로 돌아간다.
    if (done && mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.setlist == null ? '새 콘티' : '콘티 편집'),
        actions: [
          if (widget.setlist != null)
            IconButton(
              tooltip: '삭제',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(
              onPressed: _busy ? null : _save,
              child: const Text('저장'),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Song>>(
        stream: _songs,
        builder: (context, snap) {
          _songList = snap.data ?? _songList;
          return FormWidth(
            maxWidth: 800,
            child: Form(
              key: _form,
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList.list(children: _buildHeader()),
                  ),
                  SliverReorderableList(
                    itemCount: _items.length,
                    onReorderItem: (from, to) => setState(() {
                      _items.insert(to, _items.removeAt(from));
                      _rowIds.insert(to, _rowIds.removeAt(from));
                    }),
                    itemBuilder: (context, i) => _buildItem(i),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverToBoxAdapter(
                      child: OutlinedButton.icon(
                        onPressed: _addSong,
                        icon: const Icon(Icons.add),
                        label: const Text('곡 추가'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildHeader() => [
    TextFormField(
      controller: _title,
      decoration: const InputDecoration(labelText: '제목'),
      validator: (v) => (v ?? '').trim().isEmpty ? '제목을 입력해 주세요.' : null,
    ),
    const SizedBox(height: 12),
    InkWell(
      onTap: _pickDate,
      child: InputDecorator(
        decoration: const InputDecoration(labelText: '날짜'),
        child: Text(formatDate(_date)),
      ),
    ),
    const SizedBox(height: 12),
    TextFormField(
      controller: _memo,
      decoration: const InputDecoration(
        labelText: '메모 (선택)',
        hintText: '예: 3곡 후 기도, 마지막 곡 반복',
      ),
      maxLines: null,
    ),
    const SizedBox(height: 16),
    Text('곡 순서', style: Theme.of(context).textTheme.titleMedium),
    if (_items.isEmpty)
      const Padding(
        padding: EdgeInsets.only(top: 8),
        child: Text('아래 "곡 추가"로 곡을 넣으세요.'),
      ),
  ];

  Widget _buildItem(int i) {
    final item = _items[i];
    final song = _song(item.songId);
    final intro = song == null ? item.intro ?? [] : item.introFor(song);
    final keys = MusicKey.parse(item.originalKey).isMinor
        ? MusicKey.minorKeys
        : MusicKey.majorKeys;
    final current = MusicKey.parse(item.key);

    return Material(
      key: ValueKey(_rowIds[i]),
      child: ListTile(
        leading: ReorderableDragStartListener(
          index: i,
          child: const Icon(Icons.drag_handle),
        ),
        title: Text('${i + 1}. ${item.title}'),
        subtitle: Text(
          [
            if (intro.isNotEmpty) 'Intro ${formatProgression(intro)}',
            if (item.memo?.isNotEmpty ?? false) item.memo!,
          ].join('\n'),
        ),
        onTap: () => _editItem(i),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<MusicKey>(
              value: keys.firstWhere((k) => k == current),
              underline: const SizedBox.shrink(),
              items: [
                for (final k in keys)
                  DropdownMenuItem(value: k, child: Text(k.name)),
              ],
              onChanged: (k) =>
                  setState(() => _items[i] = item.withKey(k!.name)),
            ),
            IconButton(
              tooltip: '빼기',
              icon: const Icon(Icons.close),
              onPressed: () => setState(() {
                _items.removeAt(i);
                _rowIds.removeAt(i);
              }),
            ),
          ],
        ),
      ),
    );
  }
}

/// 곡 목록에서 하나 고르기 (검색 가능).
class _SongPicker extends StatefulWidget {
  const _SongPicker({required this.songs});

  final List<Song> songs;

  @override
  State<_SongPicker> createState() => _SongPickerState();
}

class _SongPickerState extends State<_SongPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.songs
        .where((s) => s.title.toLowerCase().contains(_query))
        .toList();
    return AlertDialog(
      title: const Text('곡 추가'),
      contentPadding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
      content: SizedBox(
        width: 400,
        height: 480,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: '제목 검색',
                ),
                onChanged: (v) =>
                    setState(() => _query = v.trim().toLowerCase()),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        widget.songs.isEmpty
                            ? '곡 목록이 비어 있습니다.\n"곡" 탭에서 먼저 곡을 등록하세요.'
                            : '검색 결과가 없습니다.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView(
                      children: [
                        for (final s in filtered)
                          ListTile(
                            leading: CircleAvatar(child: Text(s.originalKey)),
                            title: Text(s.title),
                            subtitle: s.artist == null ? null : Text(s.artist!),
                            onTap: () => Navigator.pop(context, s),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }
}

/// 콘티 항목 하나 편집: 조, 인트로/아웃트로, 메모.
class _ItemDialog extends StatefulWidget {
  const _ItemDialog({required this.item, this.song});

  final SetlistItem item;
  final Song? song;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  final _form = GlobalKey<FormState>();
  late MusicKey _key = MusicKey.parse(widget.item.key);
  late final _intro = TextEditingController(
    text: _initial(widget.item.intro, widget.song?.intro),
  );
  late final _outro = TextEditingController(
    text: _initial(widget.item.outro, widget.song?.outro),
  );
  late final _memo = TextEditingController(text: widget.item.memo);

  /// 따로 정한 코드가 없으면 곡 기본값을 이 조로 옮겨서 채운다.
  String _initial(List<String>? own, List<String>? songDefault) =>
      (own ?? widget.item.transposer.progression(songDefault ?? [])).join(' ');

  @override
  void dispose() {
    _intro.dispose();
    _outro.dispose();
    _memo.dispose();
    super.dispose();
  }

  /// 조를 바꾸면 입력란의 코드도 같이 옮긴다.
  void _changeKey(MusicKey key) {
    final move = Transposer(_key, key);
    setState(() {
      _intro.text = move.progression(splitProgression(_intro.text)).join(' ');
      _outro.text = move.progression(splitProgression(_outro.text)).join(' ');
      _key = key;
    });
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    final intro = splitProgression(_intro.text);
    final outro = splitProgression(_outro.text);
    final song = widget.song;
    // 곡 기본값을 옮긴 것과 같으면 따로 저장하지 않는다 (곡 기본값이 바뀌면 따라가도록).
    final fromOriginal = Transposer(
      MusicKey.parse(widget.item.originalKey),
      _key,
    );
    final defaultIntro = song == null
        ? null
        : fromOriginal.progression(song.intro);
    final defaultOutro = song == null
        ? null
        : fromOriginal.progression(song.outro);
    final memo = _memo.text.trim();
    Navigator.pop(
      context,
      SetlistItem(
        songId: widget.item.songId,
        title: widget.item.title,
        originalKey: widget.item.originalKey,
        key: _key.name,
        intro: _sameList(intro, defaultIntro) ? null : intro,
        outro: _sameList(outro, defaultOutro) ? null : outro,
        memo: memo.isEmpty ? null : memo,
      ),
    );
  }

  static bool _sameList(List<String> a, List<String>? b) =>
      b != null &&
      a.length == b.length &&
      a.indexed.every((e) => b[e.$1] == e.$2);

  String? _validate(String? value) {
    final bad = invalidChords(splitProgression(value ?? ''));
    return bad.isEmpty ? null : '코드로 읽을 수 없음: ${bad.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final keys = MusicKey.parse(widget.item.originalKey).isMinor
        ? MusicKey.minorKeys
        : MusicKey.majorKeys;
    return AlertDialog(
      title: Text(widget.item.title),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<MusicKey>(
                  initialValue: keys.firstWhere((k) => k == _key),
                  decoration: InputDecoration(
                    labelText: '부를 조 (원래 ${widget.item.originalKey})',
                  ),
                  items: [
                    for (final k in keys)
                      DropdownMenuItem(value: k, child: Text(k.name)),
                  ],
                  onChanged: (k) => _changeKey(k!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _intro,
                  decoration: const InputDecoration(labelText: '인트로 코드'),
                  validator: _validate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _outro,
                  decoration: const InputDecoration(labelText: '아웃트로 코드'),
                  validator: _validate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _memo,
                  decoration: const InputDecoration(
                    labelText: '메모',
                    hintText: '예: V1-C-V2-C-B-C×2',
                  ),
                  maxLines: null,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(onPressed: _submit, child: const Text('확인')),
      ],
    );
  }
}

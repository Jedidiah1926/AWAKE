import 'package:flutter/material.dart';

import '../../app/widgets.dart';
import '../../core/music/music_key.dart';
import '../../core/music/progression.dart';
import '../../core/music/transposer.dart';
import '../../data/backend.dart';
import '../../models/song.dart';
import 'song_chart_screen.dart';

/// 곡 추가/편집. 넓은 화면은 편집과 미리보기를 나란히, 좁은 화면은 탭으로.
class SongEditorScreen extends StatefulWidget {
  const SongEditorScreen({super.key, required this.data, this.song});

  final TeamData data;

  /// null이면 새 곡.
  final Song? song;

  @override
  State<SongEditorScreen> createState() => _SongEditorScreenState();
}

class _SongEditorScreenState extends State<SongEditorScreen> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.song?.title);
  late final _artist = TextEditingController(text: widget.song?.artist);
  late final _bpm = TextEditingController(text: widget.song?.bpm?.toString());
  late final _intro = TextEditingController(text: widget.song?.intro.join(' '));
  late final _outro = TextEditingController(text: widget.song?.outro.join(' '));
  late final _chordPro = TextEditingController(
    text: widget.song?.chordPro ?? _template,
  );
  late MusicKey _key = MusicKey.parse(widget.song?.originalKey ?? 'G');
  var _busy = false;

  static const _template = '''{start_of_verse}
[G]가사를 [D/F#]입력하세요
{end_of_verse}
{start_of_chorus}
[C]코드는 [D]대괄호 [G]안에
{end_of_chorus}
''';

  @override
  void initState() {
    super.initState();
    // 미리보기 갱신.
    for (final c in [_title, _artist, _bpm, _intro, _outro, _chordPro]) {
      c.addListener(_refresh);
    }
  }

  void _refresh() => setState(() {});

  @override
  void dispose() {
    for (final c in [_title, _artist, _bpm, _intro, _outro, _chordPro]) {
      c.dispose();
    }
    super.dispose();
  }

  Song _build({String? id}) {
    final bpm = int.tryParse(_bpm.text.trim());
    final artist = _artist.text.trim();
    final chordPro = _chordPro.text.trim();
    return Song(
      id: id ?? widget.song?.id ?? '',
      title: _title.text.trim(),
      artist: artist.isEmpty ? null : artist,
      originalKey: _key.name,
      bpm: bpm,
      chordPro: chordPro.isEmpty ? null : '$chordPro\n',
      scoreIds: widget.song?.scoreIds ?? const [],
      intro: splitProgression(_intro.text),
      outro: splitProgression(_outro.text),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final song = _build(id: widget.song?.id ?? widget.data.newSongId());
    setState(() => _busy = true);
    final ok = await runWithFeedback(context, () => widget.data.saveSong(song));
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final song = widget.song!;
    final ok = await confirm(
      context,
      title: '곡 삭제',
      message: '"${song.title}"을(를) 삭제할까요? 이미 만든 콘티에는 제목만 남습니다.',
    );
    if (!ok || !mounted) return;
    final done = await runWithFeedback(
      context,
      () => widget.data.deleteSong(song.id),
    );
    if (done && mounted) Navigator.of(context).pop();
  }

  String? _validateProgression(String? value) {
    final bad = invalidChords(splitProgression(value ?? ''));
    return bad.isEmpty ? null : '코드로 읽을 수 없음: ${bad.join(', ')}';
  }

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    final editor = _buildForm();
    final preview = _buildPreview();

    final actions = [
      if (widget.song != null)
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
    ];
    final title = Text(widget.song == null ? '곡 추가' : '곡 편집');

    if (wide) {
      return Scaffold(
        appBar: AppBar(title: title, actions: actions),
        body: Row(
          children: [
            Expanded(child: editor),
            const VerticalDivider(width: 1),
            Expanded(child: preview),
          ],
        ),
      );
    }
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: title,
          actions: actions,
          bottom: const TabBar(
            tabs: [
              Tab(text: '편집'),
              Tab(text: '미리보기'),
            ],
          ),
        ),
        body: TabBarView(children: [editor, preview]),
      ),
    );
  }

  Widget _buildForm() {
    final keys = [...MusicKey.majorKeys, ...MusicKey.minorKeys];
    return Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextFormField(
            controller: _title,
            decoration: const InputDecoration(labelText: '제목'),
            validator: (v) => (v ?? '').trim().isEmpty ? '제목을 입력해 주세요.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _artist,
            decoration: const InputDecoration(labelText: '아티스트 (선택)'),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<MusicKey>(
                  initialValue: keys.firstWhere((k) => k == _key),
                  decoration: const InputDecoration(labelText: '원래 조'),
                  items: [
                    for (final k in keys)
                      DropdownMenuItem(value: k, child: Text(k.name)),
                  ],
                  onChanged: (k) => setState(() => _key = k!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextFormField(
                  controller: _bpm,
                  decoration: const InputDecoration(labelText: 'BPM (선택)'),
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    final text = (v ?? '').trim();
                    if (text.isEmpty) return null;
                    final n = int.tryParse(text);
                    return n == null || n <= 0 ? '숫자를 입력해 주세요.' : null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _intro,
            decoration: const InputDecoration(
              labelText: '인트로 코드 (원래 조 기준)',
              hintText: 'G D/F# Em7 C',
            ),
            validator: _validateProgression,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _outro,
            decoration: const InputDecoration(
              labelText: '아웃트로 코드 (원래 조 기준)',
              hintText: 'C D G',
            ),
            validator: _validateProgression,
            autovalidateMode: AutovalidateMode.onUserInteraction,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _chordPro,
            decoration: const InputDecoration(
              labelText: '코드 악보 (ChordPro)',
              helperText:
                  '[코드]가사 형식. {start_of_chorus} … {end_of_chorus}로 구간 표시',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(fontFamily: 'monospace'),
            minLines: 12,
            maxLines: null,
            keyboardType: TextInputType.multiline,
          ),
        ],
      ),
    );
  }

  Widget _buildPreview() {
    final song = _build();
    return ChordChartView(
      song: song,
      transposer: Transposer(_key, _key),
      intro: song.intro,
      outro: song.outro,
    );
  }
}

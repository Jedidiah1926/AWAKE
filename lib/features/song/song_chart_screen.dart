import 'package:flutter/material.dart';

import '../../core/chordpro/chordpro.dart';
import '../../core/music/music_key.dart';
import '../../core/music/progression.dart';
import '../../core/music/transposer.dart';
import '../../models/song.dart';

/// 코드 악보 보기 + 조 바꾸기 + 인트로/아웃트로 표시.
class SongChartScreen extends StatefulWidget {
  const SongChartScreen({
    super.key,
    required this.song,
    this.initialKey,
    this.intro,
    this.outro,
    this.memo,
    this.actions = const [],
  });

  final Song song;

  /// 처음 보여줄 조. null이면 원래 조. (콘티에서 열 때 그 예배의 조)
  final String? initialKey;

  /// 콘티에서 따로 정한 인트로/아웃트로 ([initialKey] 기준). null이면 곡 기본값.
  final List<String>? intro;
  final List<String>? outro;

  /// 콘티 항목 메모 (송폼 등).
  final String? memo;

  /// 앱바에 추가할 버튼 (예: 편집).
  final List<Widget> actions;

  @override
  State<SongChartScreen> createState() => _SongChartScreenState();
}

class _SongChartScreenState extends State<SongChartScreen> {
  late final MusicKey _originalKey = MusicKey.parse(widget.song.originalKey);
  late final MusicKey _startKey = widget.initialKey == null
      ? _originalKey
      : MusicKey.parse(widget.initialKey!);
  late MusicKey _key = _startKey;

  void _shift(int semitones) =>
      setState(() => _key = _key.transpose(semitones));

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final keys = _originalKey.isMinor ? MusicKey.minorKeys : MusicKey.majorKeys;
    final fromOriginal = Transposer(_originalKey, _key);
    // 콘티에서 정한 인트로/아웃트로는 콘티 조 기준이라 거기서부터 옮긴다.
    final fromStart = Transposer(_startKey, _key);
    final intro = widget.intro != null
        ? fromStart.progression(widget.intro!)
        : fromOriginal.progression(song.intro);
    final outro = widget.outro != null
        ? fromStart.progression(widget.outro!)
        : fromOriginal.progression(song.outro);

    return Scaffold(
      appBar: AppBar(
        title: Text(song.title),
        actions: [
          IconButton(
            tooltip: '반음 내리기',
            icon: const Icon(Icons.remove),
            onPressed: () => _shift(-1),
          ),
          DropdownButton<MusicKey>(
            value: keys.firstWhere((k) => k == _key),
            underline: const SizedBox.shrink(),
            items: [
              for (final k in keys)
                DropdownMenuItem(value: k, child: Text(k.name)),
            ],
            onChanged: (k) => setState(() => _key = k!),
          ),
          IconButton(
            tooltip: '반음 올리기',
            icon: const Icon(Icons.add),
            onPressed: () => _shift(1),
          ),
          ...widget.actions,
          const SizedBox(width: 8),
        ],
      ),
      body: ChordChartView(
        song: song,
        transposer: fromOriginal,
        intro: intro,
        outro: outro,
        memo: widget.memo,
      ),
    );
  }
}

/// 곡 정보 + 인트로 + 코드 악보 + 아웃트로. 편집 화면 미리보기에도 쓴다.
class ChordChartView extends StatelessWidget {
  const ChordChartView({
    super.key,
    required this.song,
    required this.transposer,
    required this.intro,
    required this.outro,
    this.memo,
  });

  final Song song;
  final Transposer transposer;
  final List<String> intro;
  final List<String> outro;
  final String? memo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final chordPro = song.chordPro;
    final document = chordPro == null || chordPro.trim().isEmpty
        ? null
        : ChordProDocument.parse(
            ChordProDocument.transpose(chordPro, transposer),
          );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          [
            '원래 조 ${transposer.from.name} → ${transposer.to.name}',
            if (song.bpm != null) '${song.bpm} BPM',
            if (song.artist?.isNotEmpty ?? false) song.artist!,
          ].join(' · '),
          style: theme.textTheme.bodySmall,
        ),
        if (memo?.isNotEmpty ?? false)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(memo!, style: theme.textTheme.bodyMedium),
          ),
        const SizedBox(height: 12),
        if (intro.isNotEmpty) _Progression(label: 'Intro', chords: intro),
        if (document != null) ..._buildChart(theme, document),
        if (outro.isNotEmpty) _Progression(label: 'Outro', chords: outro),
        if (document == null && intro.isEmpty && outro.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 32),
            child: Text('코드 악보가 없습니다.', textAlign: TextAlign.center),
          ),
      ],
    );
  }

  List<Widget> _buildChart(ThemeData theme, ChordProDocument document) {
    final chordStyle = theme.textTheme.bodyMedium!.copyWith(
      color: theme.colorScheme.primary,
      fontWeight: FontWeight.bold,
    );
    final lyricStyle = theme.textTheme.bodyLarge!;
    final widgets = <Widget>[];
    String? currentSection;

    for (final line in document.lines) {
      if (line.section != currentSection && line.section != null) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 16, bottom: 4),
            child: Text(
              line.section!.toUpperCase(),
              style: theme.textTheme.labelLarge,
            ),
          ),
        );
      }
      currentSection = line.section;

      if (line.isComment) {
        widgets.add(
          Text(
            line.comment!,
            style: lyricStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      } else if (line.isEmpty) {
        widgets.add(const SizedBox(height: 8));
      } else {
        widgets.add(
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              for (final seg in line.segments)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      seg.chord == null ? ' ' : '${seg.chord} ',
                      style: chordStyle,
                    ),
                    Text(seg.lyric, style: lyricStyle),
                  ],
                ),
            ],
          ),
        );
      }
    }
    return widgets;
  }
}

class _Progression extends StatelessWidget {
  const _Progression({required this.label, required this.chords});

  final String label;
  final List<String> chords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 56,
            child: Text(label, style: theme.textTheme.labelLarge),
          ),
          Expanded(
            child: Text(
              formatProgression(chords),
              style: theme.textTheme.bodyLarge!.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

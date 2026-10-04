import 'package:flutter/material.dart';

import '../../core/chordpro/chordpro.dart';
import '../../core/music/music_key.dart';
import '../../core/music/transposer.dart';
import '../../models/song.dart';

/// 코드 악보 보기 + 조 바꾸기 + 인트로/아웃트로 표시.
class SongChartScreen extends StatefulWidget {
  const SongChartScreen({super.key, required this.song});

  final Song song;

  @override
  State<SongChartScreen> createState() => _SongChartScreenState();
}

class _SongChartScreenState extends State<SongChartScreen> {
  late final MusicKey _originalKey = MusicKey.parse(widget.song.originalKey);
  late MusicKey _key = _originalKey;

  Transposer get _transposer => Transposer(_originalKey, _key);

  void _shift(int semitones) =>
      setState(() => _key = _key.transpose(semitones));

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final keys = _originalKey.isMinor ? MusicKey.minorKeys : MusicKey.majorKeys;
    final document = song.chordPro == null
        ? null
        : ChordProDocument.parse(
            ChordProDocument.transpose(song.chordPro!, _transposer),
          );

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
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '원래 조 ${_originalKey.name} → ${_key.name}'
            '${song.bpm == null ? '' : ' · ${song.bpm} BPM'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (song.intro.isNotEmpty)
            _Progression(
              label: 'Intro',
              chords: _transposer.progression(song.intro),
            ),
          if (document != null) ..._buildChart(context, document),
          if (song.outro.isNotEmpty)
            _Progression(
              label: 'Outro',
              chords: _transposer.progression(song.outro),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildChart(BuildContext context, ChordProDocument document) {
    final theme = Theme.of(context);
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
              '| ${chords.join(' | ')} |',
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

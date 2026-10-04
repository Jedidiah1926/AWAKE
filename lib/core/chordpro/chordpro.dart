import '../music/music_key.dart';
import '../music/transposer.dart';

/// 코드 악보 텍스트(ChordPro 형식)를 다룬다.
///
/// ```
/// {title: 주 품에}
/// {key: G}
/// {start_of_verse}
/// [G]주 품에 품으[D/F#]소서
/// {end_of_verse}
/// ```
class ChordProDocument {
  ChordProDocument({required this.directives, required this.lines});

  /// {title: ...}, {key: ...} 같은 메타데이터. 키는 소문자.
  final Map<String, String> directives;
  final List<ChordProLine> lines;

  String? get title => directives['title'] ?? directives['t'];
  MusicKey? get key =>
      directives['key'] == null ? null : MusicKey.tryParse(directives['key']!);

  static final _directive = RegExp(r'^\{\s*([^:}]+?)\s*(?::\s*(.*?))?\s*\}$');
  static final _chord = RegExp(r'\[([^\]]*)\]');

  static ChordProDocument parse(String source) {
    final directives = <String, String>{};
    final lines = <ChordProLine>[];
    String? section;

    for (final raw in source.split(RegExp(r'\r?\n'))) {
      final line = raw.trimRight();
      final directive = _directive.firstMatch(line.trim());
      if (directive != null) {
        final name = directive.group(1)!.toLowerCase();
        final value = directive.group(2);
        switch (name) {
          case 'start_of_verse' || 'sov':
            section = value?.isNotEmpty == true ? value : 'verse';
          case 'start_of_chorus' || 'soc':
            section = value?.isNotEmpty == true ? value : 'chorus';
          case 'start_of_bridge' || 'sob':
            section = value?.isNotEmpty == true ? value : 'bridge';
          case 'end_of_verse' ||
              'eov' ||
              'end_of_chorus' ||
              'eoc' ||
              'end_of_bridge' ||
              'eob':
            section = null;
          case 'comment' || 'c':
            lines.add(ChordProLine.comment(value ?? '', section: section));
          default:
            directives[name] = value ?? '';
        }
        continue;
      }
      if (line.trimLeft().startsWith('#')) continue; // ChordPro 주석 줄
      lines.add(_parseLyricLine(line, section));
    }
    return ChordProDocument(directives: directives, lines: lines);
  }

  static ChordProLine _parseLyricLine(String line, String? section) {
    final segments = <ChordProSegment>[];
    var cursor = 0;
    String? pendingChord;
    for (final match in _chord.allMatches(line)) {
      final lyric = line.substring(cursor, match.start);
      if (lyric.isNotEmpty || pendingChord != null) {
        segments.add(ChordProSegment(chord: pendingChord, lyric: lyric));
      }
      pendingChord = match.group(1);
      cursor = match.end;
    }
    final rest = line.substring(cursor);
    if (rest.isNotEmpty || pendingChord != null) {
      segments.add(ChordProSegment(chord: pendingChord, lyric: rest));
    }
    return ChordProLine.lyrics(segments, section: section);
  }

  /// [source]의 모든 [코드]와 {key:}를 옮긴 새 텍스트를 돌려준다.
  /// 원문의 줄 구성, 주석, 공백은 그대로 둔다.
  static String transpose(String source, Transposer transposer) {
    return source
        .split('\n')
        .map((line) {
          final directive = _directive.firstMatch(line.trim());
          if (directive != null) {
            final name = directive.group(1)!.toLowerCase();
            if (name == 'key') return '{key: ${transposer.to.name}}';
            return line;
          }
          return line.replaceAllMapped(
            _chord,
            (m) => '[${transposer.symbol(m.group(1)!)}]',
          );
        })
        .join('\n');
  }
}

class ChordProLine {
  ChordProLine.lyrics(this.segments, {this.section}) : comment = null;
  ChordProLine.comment(String this.comment, {this.section})
    : segments = const [];

  final List<ChordProSegment> segments;
  final String? comment;

  /// verse / chorus / bridge 등 속한 구간. 없으면 null.
  final String? section;

  bool get isComment => comment != null;
  bool get isEmpty => !isComment && segments.isEmpty;
}

/// 코드 하나와 그 아래 가사 조각.
class ChordProSegment {
  const ChordProSegment({this.chord, required this.lyric});

  final String? chord;
  final String lyric;
}

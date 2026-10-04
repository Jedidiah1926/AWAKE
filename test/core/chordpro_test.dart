import 'package:awake/core/chordpro/chordpro.dart';
import 'package:awake/core/music/music_key.dart';
import 'package:awake/core/music/transposer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const source = '''
{title: 테스트}
{key: G}
{start_of_chorus}
[G]찬양 [D/F#]하리
{c: 2번 반복}
{end_of_chorus}
그냥 가사''';

  test('메타데이터와 구간을 읽는다', () {
    final doc = ChordProDocument.parse(source);
    expect(doc.title, '테스트');
    expect(doc.key, MusicKey.parse('G'));

    final chorus = doc.lines.where((l) => l.section == 'chorus').toList();
    expect(chorus, hasLength(2));
    expect(chorus[0].segments.map((s) => s.chord), ['G', 'D/F#']);
    expect(chorus[0].segments.map((s) => s.lyric), ['찬양 ', '하리']);
    expect(chorus[1].comment, '2번 반복');

    expect(doc.lines.last.section, isNull);
    expect(doc.lines.last.segments.single.chord, isNull);
  });

  test('가사 없이 코드만 있는 줄', () {
    final doc = ChordProDocument.parse('[G] [C] [D]');
    expect(doc.lines.single.segments.map((s) => s.chord), ['G', 'C', 'D']);
  });

  test('조옮김은 코드와 {key}만 바꾼다', () {
    final moved = ChordProDocument.transpose(
      source,
      Transposer(MusicKey.parse('G'), MusicKey.parse('A')),
    );
    expect(moved, contains('{key: A}'));
    expect(moved, contains('[A]찬양 [E/G#]하리'));
    expect(moved, contains('{title: 테스트}'));
    expect(moved, contains('그냥 가사'));
  });
}

import 'dart:ui';

import 'package:awake/models/annotation.dart';
import 'package:awake/models/setlist.dart';
import 'package:awake/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SetlistItem', () {
    const song = Song(
      id: 's1',
      title: '곡',
      originalKey: 'G',
      intro: ['G', 'D/F#', 'Em7', 'C'],
      outro: ['C', 'D', 'G'],
    );

    test('곡 기본 인트로/아웃트로를 부를 조로 옮긴다', () {
      final item = SetlistItem.fromSong(song, key: 'A');
      expect(item.introFor(song), ['A', 'E/G#', 'F#m7', 'D']);
      expect(item.outroFor(song), ['D', 'E', 'A']);
    });

    test('직접 적은 인트로가 있으면 그것을 쓰고, 조를 바꾸면 같이 옮긴다', () {
      const item = SetlistItem(
        songId: 's1',
        title: '곡',
        originalKey: 'G',
        key: 'G',
        intro: ['Em7', 'C', 'G', 'D'],
      );
      expect(item.introFor(song), ['Em7', 'C', 'G', 'D']);

      final moved = item.withKey('Bb');
      expect(moved.key, 'Bb');
      expect(moved.introFor(song), ['Gm7', 'Eb', 'Bb', 'F']);
      expect(moved.outroFor(song), ['Eb', 'F', 'Bb']);
    });

    test('Firestore 맵 왕복', () {
      final setlist = Setlist(
        id: 'x',
        title: '주일 2부',
        date: DateTime.utc(2026, 10, 4),
        items: [SetlistItem.fromSong(song, key: 'A')],
      );
      final back = Setlist.fromMap('x', setlist.toMap());
      expect(back.title, '주일 2부');
      expect(back.date, setlist.date);
      expect(back.items.single.key, 'A');
      expect(back.items.single.intro, isNull);
    });
  });

  group('Annotation', () {
    test('손글씨 맵 왕복', () {
      const ink = InkAnnotation(
        id: 'a',
        authorId: 'u1',
        page: 1,
        visibility: AnnotationVisibility.private,
        color: Color(0xFFE53935),
        width: 0.004,
        strokes: [
          InkStroke(
            [Offset(0.1, 0.2), Offset(0.123456, 0.3)],
            pressures: [0.5, 0.7],
          ),
        ],
      );
      final back = Annotation.fromMap('a', ink.toMap()) as InkAnnotation;
      expect(back.page, 1);
      expect(back.visibility, AnnotationVisibility.private);
      expect(back.color, const Color(0xFFE53935));
      expect(back.strokes.single.points, [
        const Offset(0.1, 0.2),
        const Offset(0.1235, 0.3),
      ]);
      expect(back.strokes.single.pressures, [0.5, 0.7]);
      expect(back.bounds, const Rect.fromLTRB(0.1, 0.2, 0.1235, 0.3));
    });

    test('Firestore에 중첩 배열을 넣지 않는다', () {
      const ink = InkAnnotation(
        id: 'a',
        authorId: 'u1',
        page: 0,
        visibility: AnnotationVisibility.team,
        color: Color(0xFF000000),
        width: 0.004,
        strokes: [
          InkStroke([Offset(0, 0), Offset(1, 1)]),
        ],
      );
      final strokes = ink.toMap()['strokes'] as List;
      expect(strokes.single, isA<Map>());
      expect((strokes.single as Map)['p'], everyElement(isA<double>()));
    });

    test('글자 주석과 가림 박스 맵 왕복', () {
      const text = TextAnnotation(
        id: 't',
        authorId: 'u1',
        page: 0,
        visibility: AnnotationVisibility.team,
        color: Color(0xFF1E88E5),
        position: Offset(0.5, 0.25),
        text: '2절 후 간주 4마디',
        fontSize: 0.02,
        setlistId: 'sunday',
      );
      final t = Annotation.fromMap('t', text.toMap()) as TextAnnotation;
      expect(t.text, '2절 후 간주 4마디');
      expect(t.position, const Offset(0.5, 0.25));
      expect(t.setlistId, 'sunday');

      const mask = MaskAnnotation(
        id: 'm',
        authorId: 'u1',
        page: 0,
        visibility: AnnotationVisibility.team,
        color: Color(0xFFFFFFFF),
        rect: Rect.fromLTWH(0.1, 0.1, 0.05, 0.02),
        replacement: 'D/F#',
      );
      final m = Annotation.fromMap('m', mask.toMap()) as MaskAnnotation;
      expect(m.rect, const Rect.fromLTWH(0.1, 0.1, 0.05, 0.02));
      expect(m.replacement, 'D/F#');
    });
  });
}

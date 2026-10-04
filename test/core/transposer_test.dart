import 'package:awake/core/music/chord.dart';
import 'package:awake/core/music/music_key.dart';
import 'package:awake/core/music/transposer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MusicKey key(String s) => MusicKey.parse(s);
  String move(String from, String to, String chord) =>
      Transposer(key(from), key(to)).symbol(chord);

  group('Chord.tryParse', () {
    test('근음, 성격, 베이스를 나눈다', () {
      expect(Chord.parse('D/F#'), const Chord(root: 'D', bass: 'F#'));
      expect(Chord.parse('Em7'), const Chord(root: 'E', quality: 'm7'));
      expect(Chord.parse('Bbmaj7'), const Chord(root: 'Bb', quality: 'maj7'));
      expect(Chord.parse('C#m7b5'), const Chord(root: 'C#', quality: 'm7b5'));
      expect(Chord.parse('D7sus4'), const Chord(root: 'D', quality: '7sus4'));
      expect(
        Chord.parse('Gadd9/B'),
        const Chord(root: 'G', quality: 'add9', bass: 'B'),
      );
      expect(Chord.parse('F♯m'), const Chord(root: 'F#', quality: 'm'));
    });

    test('코드가 아닌 글자는 거른다 (OCR 결과 분류용)', () {
      for (final word in ['주님', 'Verse', 'Chorus', 'Go', 'x2', '', 'H7']) {
        expect(Chord.isChord(word), isFalse, reason: word);
      }
    });
  });

  group('MusicKey', () {
    test('반음 차이는 가까운 쪽으로', () {
      expect(key('G').semitonesTo(key('A')), 2);
      expect(key('G').semitonesTo(key('E')), -3);
      expect(key('C').semitonesTo(key('F#')), 6);
    });

    test('옮긴 조 이름은 흔히 쓰는 표기', () {
      expect(key('G').transpose(-1).name, 'F#');
      expect(key('C').transpose(1).name, 'Db');
      expect(key('Am').transpose(1).name, 'Bbm');
      expect(key('Am').transpose(-1).name, 'G#m');
    });

    test('음계음은 조표대로 적는다', () {
      expect(key('F').spell(10), 'Bb');
      expect(key('E').spell(8), 'G#');
      expect(key('F#').spell(5), 'E#');
      expect(key('Gb').spell(11), 'Cb');
      expect(key('Dm').spell(10), 'Bb');
    });
  });

  group('Transposer', () {
    test('G → A', () {
      expect(move('G', 'A', 'G'), 'A');
      expect(move('G', 'A', 'D/F#'), 'E/G#');
      expect(move('G', 'A', 'Em7'), 'F#m7');
      expect(move('G', 'A', 'Csus2'), 'Dsus2');
    });

    test('플랫 조로 가면 플랫으로 적는다', () {
      expect(move('G', 'Bb', 'D/F#'), 'F/A');
      expect(move('G', 'Eb', 'Em7'), 'Cm7');
      expect(move('G', 'Ab', 'C'), 'Db');
      expect(move('C', 'Eb', 'E7'), 'G7');
      expect(move('D', 'Db', 'A/C#'), 'Ab/C');
    });

    test('샵 조에서도 bVII, bIII은 플랫으로', () {
      expect(move('C', 'G', 'Bb'), 'F');
      expect(move('C', 'D', 'Bb'), 'C');
      expect(move('C', 'G', 'Eb'), 'Bb');
      expect(move('C', 'D', 'Ab'), 'Bb');
    });

    test('C조의 비음계음', () {
      expect(move('G', 'C', 'A/C#'), 'D/F#');
      expect(move('D', 'C', 'C'), 'Bb');
    });

    test('단조', () {
      expect(move('Em', 'Dm', 'B7'), 'A7');
      expect(move('Am', 'Cm', 'E7'), 'G7');
      expect(move('Am', 'Cm', 'F'), 'Ab');
    });

    test('코드가 아니면 그대로 둔다', () {
      expect(move('G', 'A', 'N.C.'), 'N.C.');
    });

    test('인트로 진행', () {
      final t = Transposer.bySemitones(key('G'), 2);
      expect(t.to.name, 'A');
      expect(t.progression(['G', 'D/F#', 'Em7', 'C']), [
        'A',
        'E/G#',
        'F#m7',
        'D',
      ]);
    });

    test('올렸다 내리면 원래대로', () {
      const chords = ['G', 'D/F#', 'Em7', 'Cmaj7', 'Am7', 'D7sus4', 'Bm'];
      for (final target in MusicKey.majorKeys) {
        final there = Transposer(key('G'), target).progression(chords);
        final back = Transposer(target, key('G')).progression(there);
        expect(back, chords, reason: 'G → ${target.name} → G');
      }
    });
  });
}

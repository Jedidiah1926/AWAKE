import 'chord.dart';
import 'music_key.dart';

/// 원래 조 → 목표 조로 코드를 옮긴다.
class Transposer {
  Transposer(this.from, this.to) : semitones = from.semitonesTo(to);

  /// 원래 조에서 반음 단위로 올리거나 내린다.
  factory Transposer.bySemitones(MusicKey from, int semitones) =>
      Transposer(from, from.transpose(semitones));

  final MusicKey from;
  final MusicKey to;
  final int semitones;

  Chord chord(Chord chord) => chord.transpose(semitones, to);

  /// 코드 문자열 하나를 옮긴다. 코드가 아니면 그대로 돌려준다.
  String symbol(String symbol) {
    final parsed = Chord.tryParse(symbol);
    return parsed == null ? symbol : chord(parsed).toString();
  }

  /// 인트로/아웃트로처럼 코드 목록을 옮긴다.
  List<String> progression(List<String> symbols) => [
    for (final s in symbols) symbol(s),
  ];
}

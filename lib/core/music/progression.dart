import 'chord.dart';

/// "G D/F# | Em7, C" 같은 입력을 코드 목록으로 나눈다.
/// 공백, 마디선(|), 쉼표, 하이픈(-)으로 구분한다.
List<String> splitProgression(String input) => input
    .split(RegExp(r'[\s|,]+|\s+-\s+'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();

/// 코드로 읽을 수 없는 항목. 모두 코드면 빈 목록.
List<String> invalidChords(List<String> chords) => [
  for (final c in chords)
    if (!Chord.isChord(c)) c,
];

/// 화면 표시용: "| G | D/F# | Em7 |".
String formatProgression(List<String> chords) =>
    chords.isEmpty ? '' : '| ${chords.join(' | ')} |';

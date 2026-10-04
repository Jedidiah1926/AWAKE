import 'music_key.dart';
import 'pitch.dart';

/// 코드 기호 하나 (예: "D/F#", "Em7", "Bbsus4", "C#m7b5").
///
/// 근음, 나머지 코드 성격(quality), 슬래시 베이스로 나눠서 보관한다.
/// quality는 해석하지 않고 그대로 둔다. 조옮김에는 근음과 베이스만 필요하기 때문.
class Chord {
  const Chord({required this.root, this.quality = '', this.bass});

  final String root;
  final String quality;
  final String? bass;

  static final _pattern = RegExp(
    r'^([A-G][#b♯♭]?)' // 근음
    r"((?:maj|min|dim|aug|sus|add|alt|no|omit|M|m|Δ|ø|°|\+|-|[0-9]|[#b♯♭]|\(|\)|,|\^)*)" // 성격
    r'(?:/([A-G][#b♯♭]?))?$', // 베이스
  );

  /// 코드 기호로 해석할 수 없으면 null. OCR 결과에서 코드만 골라낼 때도 쓴다.
  static Chord? tryParse(String input) {
    final text = input.trim();
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    return Chord(
      root: _normalize(match.group(1)!),
      quality: match.group(2)!,
      bass: match.group(3) == null ? null : _normalize(match.group(3)!),
    );
  }

  static Chord parse(String input) =>
      tryParse(input) ?? (throw FormatException('알 수 없는 코드: $input'));

  static bool isChord(String input) => tryParse(input) != null;

  static String _normalize(String note) =>
      note.replaceAll('♯', '#').replaceAll('♭', 'b');

  int get rootPitch => pitchClassOf(root)!;
  int? get bassPitch => bass == null ? null : pitchClassOf(bass!);

  /// [semitones]만큼 옮기고, 음 이름은 [targetKey]의 표기 규칙을 따른다.
  Chord transpose(int semitones, MusicKey targetKey) => Chord(
    root: targetKey.spell(rootPitch + semitones),
    quality: quality,
    bass: bass == null ? null : targetKey.spell(bassPitch! + semitones),
  );

  @override
  String toString() => bass == null ? '$root$quality' : '$root$quality/$bass';

  @override
  bool operator ==(Object other) =>
      other is Chord &&
      other.root == root &&
      other.quality == quality &&
      other.bass == bass;

  @override
  int get hashCode => Object.hash(root, quality, bass);
}

import 'pitch.dart';

/// 조성(키). 장조/단조와 그 조의 음 표기 규칙을 가진다.
class MusicKey {
  MusicKey._(this.tonic, this.isMinor) : tonicPitch = pitchClassOf(tonic)!;

  /// 으뜸음 표기 (예: "Bb", "F#").
  final String tonic;
  final bool isMinor;
  final int tonicPitch;

  late final List<String> _spellings = _buildSpellings();

  /// 피치 클래스별로 많이 쓰는 조 이름. 조옮김 결과 키는 이 표기를 따른다.
  static const _majorNames = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B', //
  ];
  static const _minorNames = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'G#', 'A', 'Bb', 'B', //
  ];

  static const _majorScale = [0, 2, 4, 5, 7, 9, 11];
  static const _minorScale = [0, 2, 3, 5, 7, 8, 10];

  /// 조 선택 UI 등에 쓸 12개 장조.
  static List<MusicKey> get majorKeys => [
    for (final n in _majorNames) MusicKey._(n, false),
  ];

  /// 12개 단조.
  static List<MusicKey> get minorKeys => [
    for (final n in _minorNames) MusicKey._(n, true),
  ];

  /// "G", "Bb", "F#m", "Ebm" 같은 문자열을 해석한다. 실패하면 null.
  static MusicKey? tryParse(String input) {
    final match = RegExp(r'^\s*([A-G][#b♯♭]?)\s*(m|min|minor)?\s*$')
        .firstMatch(input);
    if (match == null) return null;
    final tonic = match.group(1)!.replaceAll('♯', '#').replaceAll('♭', 'b');
    if (pitchClassOf(tonic) == null) return null;
    return MusicKey._(tonic, match.group(2) != null);
  }

  static MusicKey parse(String input) =>
      tryParse(input) ?? (throw FormatException('알 수 없는 조: $input'));

  /// [semitones]만큼 옮긴 조. 이름은 흔히 쓰는 표기(Db, F#, Bbm 등)로 정한다.
  MusicKey transpose(int semitones) {
    final pc = mod12(tonicPitch + semitones);
    return MusicKey._(isMinor ? _minorNames[pc] : _majorNames[pc], isMinor);
  }

  /// 이 조에서 [other] 조로 가려면 몇 반음을 옮겨야 하는지 (-5 ~ +6).
  int semitonesTo(MusicKey other) {
    final diff = mod12(other.tonicPitch - tonicPitch);
    return diff > 6 ? diff - 12 : diff;
  }

  /// 조표에 플랫이 붙는 조인지. 비음계음 표기에 쓴다.
  bool get usesFlats => _scaleSpelling().any((n) => n.endsWith('b'));
  bool get usesSharps => _scaleSpelling().any((n) => n.endsWith('#'));

  /// 이 조 안에서 [pitchClass]를 어떻게 적는지.
  String spell(int pitchClass) => _spellings[mod12(pitchClass)];

  List<String> _scaleSpelling() {
    final startLetter = letters.indexOf(tonic[0]);
    final scale = isMinor ? _minorScale : _majorScale;
    return [
      for (var i = 0; i < 7; i++)
        spellWithLetter(
              letters[(startLetter + i) % 7],
              tonicPitch + scale[i],
            ) ??
            // 이론상 겹임시표가 필요한 경우 (예: G#m의 F##) 는 단순 표기로.
            _fallback(tonicPitch + scale[i]),
    ];
  }

  /// 피치 클래스 → 표기 표를 만든다.
  ///
  /// 1. 그 조의 음계음은 음계 표기를 따른다 (F#조의 E#, Gb조의 Cb 포함).
  /// 2. 나머지 중 자연음(C, D, E ...)은 그대로 쓴다.
  /// 3. 남은 음은 조표가 플랫이면 플랫, 샵이면 샵으로 쓴다.
  ///    단, 샵 조에서도 빌려온 화음(bIII, bVII)이 흔하므로 Eb, Bb는 플랫으로 쓴다.
  ///    C/Am처럼 조표가 없는 조는 C# Eb F# Ab Bb를 쓴다.
  List<String> _buildSpellings() {
    final table = List<String?>.filled(12, null);
    for (final name in _scaleSpelling()) {
      table[pitchClassOf(name)!] = name;
    }
    final flats = usesFlats;
    final sharps = usesSharps;
    for (var pc = 0; pc < 12; pc++) {
      if (table[pc] != null) continue;
      final natural = letters.where((l) => naturalPitchOf(l) == pc);
      if (natural.isNotEmpty) {
        table[pc] = natural.first;
      } else if (flats) {
        table[pc] = _flatNames[pc];
      } else if (sharps) {
        table[pc] = (pc == 3 || pc == 10) ? _flatNames[pc] : _sharpNames[pc];
      } else {
        table[pc] = _neutralNames[pc];
      }
    }
    return table.cast<String>();
  }

  static String _fallback(int pc) => _sharpNames[mod12(pc)];

  static const _sharpNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', //
  ];
  static const _flatNames = [
    'C', 'Db', 'D', 'Eb', 'E', 'F', 'Gb', 'G', 'Ab', 'A', 'Bb', 'B', //
  ];
  static const _neutralNames = [
    'C', 'C#', 'D', 'Eb', 'E', 'F', 'F#', 'G', 'Ab', 'A', 'Bb', 'B', //
  ];

  String get name => isMinor ? '${tonic}m' : tonic;

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      other is MusicKey &&
      other.tonicPitch == tonicPitch &&
      other.isMinor == isMinor;

  @override
  int get hashCode => Object.hash(tonicPitch, isMinor);
}

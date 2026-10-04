/// 음 이름(C, F#, Bb ...)과 피치 클래스(0~11) 사이의 변환.
library;

const _naturalPitch = {'C': 0, 'D': 2, 'E': 4, 'F': 5, 'G': 7, 'A': 9, 'B': 11};

const letters = ['C', 'D', 'E', 'F', 'G', 'A', 'B'];

int naturalPitchOf(String letter) {
  final pc = _naturalPitch[letter];
  if (pc == null) throw ArgumentError.value(letter, 'letter');
  return pc;
}

/// "C", "F#", "Bb", "Cb", "E#" 같은 음 이름을 피치 클래스로 바꾼다.
/// 인식할 수 없으면 null.
int? pitchClassOf(String name) {
  if (name.isEmpty) return null;
  final base = _naturalPitch[name[0]];
  if (base == null) return null;
  var pc = base;
  for (final ch in name.substring(1).split('')) {
    switch (ch) {
      case '#' || '♯':
        pc++;
      case 'b' || '♭':
        pc--;
      default:
        return null;
    }
  }
  return pc % 12;
}

/// [letter] 글자로 [pitchClass]를 표기한다. 예: ('E', 3) → "Eb".
/// 임시표가 두 개 이상 필요하면 null.
String? spellWithLetter(String letter, int pitchClass) {
  final diff = ((pitchClass - naturalPitchOf(letter)) % 12 + 18) % 12 - 6;
  return switch (diff) {
    0 => letter,
    1 => '$letter#',
    -1 => '${letter}b',
    _ => null,
  };
}

int mod12(int value) => value % 12;

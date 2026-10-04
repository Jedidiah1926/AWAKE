import '../../models/song.dart';

/// Firebase 연결 전 화면 확인용 예제 곡.
const sampleSong = Song(
  id: 'sample',
  title: '예제 찬양',
  originalKey: 'G',
  bpm: 72,
  intro: ['G', 'D/F#', 'Em7', 'Csus2'],
  outro: ['C', 'D', 'G'],
  chordPro: '''
{title: 예제 찬양}
{key: G}
{start_of_verse}
[G]주님의 사랑 [D/F#]날 감싸네
[Em7]나의 모든 [C]날 동안
{end_of_verse}
{start_of_chorus}
[C]찬양 [D]하리 [Bm7]주의 이[Em]름
[Am7]영원히 [D7sus4]노래하[G]리
{end_of_chorus}
''',
);

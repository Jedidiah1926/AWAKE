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

const _sampleMinorSong = Song(
  id: 'sample-minor',
  title: '예제 단조 찬양',
  originalKey: 'Em',
  bpm: 68,
  intro: ['Em', 'C', 'G', 'D'],
  outro: ['C', 'D', 'Em'],
  chordPro: '''
{start_of_verse}
[Em]깊은 밤 [C]주를 찾네
[G]나의 [D]빛 되신 주
{end_of_verse}
{start_of_chorus}
[Am7]주만 [B7]바라[Em]보리
{end_of_chorus}
''',
);

/// 데모 모드에 넣을 곡들.
const sampleSongs = [sampleSong, _sampleMinorSong];

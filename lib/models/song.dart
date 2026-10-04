/// 팀 곡 목록에 등록된 곡.
///
/// Firestore: teams/{teamId}/songs/{songId}
class Song {
  const Song({
    required this.id,
    required this.title,
    required this.originalKey,
    this.artist,
    this.bpm,
    this.chordPro,
    this.scoreIds = const [],
    this.intro = const [],
    this.outro = const [],
  });

  final String id;
  final String title;
  final String? artist;

  /// 악보 원래 조 (예: "G", "Bbm").
  final String originalKey;
  final int? bpm;

  /// 코드·가사 악보 (ChordPro 텍스트). 이미지 악보만 있으면 null.
  final String? chordPro;

  /// 업로드된 악보 이미지/PDF (teams/{teamId}/scores/{scoreId}).
  final List<String> scoreIds;

  /// 기본 인트로/아웃트로 코드 (원래 조 기준).
  final List<String> intro;
  final List<String> outro;

  factory Song.fromMap(String id, Map<String, dynamic> map) => Song(
    id: id,
    title: map['title'] as String,
    artist: map['artist'] as String?,
    originalKey: map['originalKey'] as String,
    bpm: (map['bpm'] as num?)?.toInt(),
    chordPro: map['chordPro'] as String?,
    scoreIds: List<String>.from(map['scoreIds'] as List? ?? const []),
    intro: List<String>.from(map['intro'] as List? ?? const []),
    outro: List<String>.from(map['outro'] as List? ?? const []),
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'artist': artist,
    'originalKey': originalKey,
    'bpm': bpm,
    'chordPro': chordPro,
    'scoreIds': scoreIds,
    'intro': intro,
    'outro': outro,
  };
}

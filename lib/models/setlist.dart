import '../core/music/music_key.dart';
import '../core/music/transposer.dart';
import 'song.dart';

/// 한 번의 예배 콘티.
///
/// Firestore: teams/{teamId}/setlists/{setlistId}
/// 곡 순서와 키를 문서 하나에 담아서, 콘티를 열 때 읽기 1회로 끝나게 한다.
class Setlist {
  const Setlist({
    required this.id,
    required this.title,
    required this.date,
    required this.items,
    this.memo,
  });

  final String id;
  final String title;
  final DateTime date;
  final List<SetlistItem> items;
  final String? memo;

  factory Setlist.fromMap(String id, Map<String, dynamic> map) => Setlist(
    id: id,
    title: map['title'] as String,
    date: DateTime.parse(map['date'] as String),
    memo: map['memo'] as String?,
    items: [
      for (final item in map['items'] as List? ?? const [])
        SetlistItem.fromMap(Map<String, dynamic>.from(item as Map)),
    ],
  );

  Map<String, dynamic> toMap() => {
    'title': title,
    'date': date.toIso8601String(),
    'memo': memo,
    'items': [for (final item in items) item.toMap()],
  };
}

/// 콘티 안의 곡 하나. 이 예배에서 쓸 키와 인트로/아웃트로를 따로 가진다.
class SetlistItem {
  const SetlistItem({
    required this.songId,
    required this.title,
    required this.originalKey,
    required this.key,
    this.intro,
    this.outro,
    this.memo,
  });

  /// 곡 정보를 가져와서 콘티 항목을 만든다. 키를 정하지 않으면 원래 조.
  factory SetlistItem.fromSong(Song song, {String? key}) => SetlistItem(
    songId: song.id,
    title: song.title,
    originalKey: song.originalKey,
    key: key ?? song.originalKey,
  );

  final String songId;

  /// 목록 표시용 사본 (곡 문서를 따로 읽지 않기 위해).
  final String title;
  final String originalKey;

  /// 이번 예배에서 부를 조.
  final String key;

  /// 이번 예배용 인트로/아웃트로 (부를 조 기준). null이면 곡 기본값을 옮겨서 쓴다.
  final List<String>? intro;
  final List<String>? outro;

  /// 송폼, 엔딩 반복 같은 메모 (예: "V1-C-V2-C-B-C×2").
  final String? memo;

  Transposer get transposer =>
      Transposer(MusicKey.parse(originalKey), MusicKey.parse(key));

  /// 이 항목에서 실제로 칠 인트로 코드.
  List<String> introFor(Song song) =>
      intro ?? transposer.progression(song.intro);

  List<String> outroFor(Song song) =>
      outro ?? transposer.progression(song.outro);

  /// 조를 바꾼다. 직접 적어둔 인트로/아웃트로도 같이 옮긴다.
  SetlistItem withKey(String newKey) {
    final move = Transposer(MusicKey.parse(key), MusicKey.parse(newKey));
    return SetlistItem(
      songId: songId,
      title: title,
      originalKey: originalKey,
      key: newKey,
      intro: intro == null ? null : move.progression(intro!),
      outro: outro == null ? null : move.progression(outro!),
      memo: memo,
    );
  }

  factory SetlistItem.fromMap(Map<String, dynamic> map) => SetlistItem(
    songId: map['songId'] as String,
    title: map['title'] as String,
    originalKey: map['originalKey'] as String,
    key: map['key'] as String,
    intro: (map['intro'] as List?)?.cast<String>(),
    outro: (map['outro'] as List?)?.cast<String>(),
    memo: map['memo'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'songId': songId,
    'title': title,
    'originalKey': originalKey,
    'key': key,
    'intro': intro,
    'outro': outro,
    'memo': memo,
  };
}

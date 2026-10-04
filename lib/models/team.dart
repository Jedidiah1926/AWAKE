/// 팀 안에서의 역할.
enum TeamRole {
  /// 팀 관리, 멤버 역할 변경, 초대 코드 관리.
  leader,

  /// 곡/콘티 편집 (인도자, 반주자 등).
  editor,

  /// 보기 + 자기 주석.
  member;

  bool get canEdit => this == leader || this == editor;
  bool get canManage => this == leader;

  String get label => switch (this) {
    leader => '리더',
    editor => '편집자',
    member => '멤버',
  };
}

/// 팀.
///
/// Firestore: teams/{teamId}
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.ownerId,
    this.inviteCode,
  });

  final String id;
  final String name;
  final String ownerId;

  /// 팀원 초대 코드. invites/{code} 문서와 짝을 이룬다.
  final String? inviteCode;

  factory Team.fromMap(String id, Map<String, dynamic> map) => Team(
    id: id,
    name: map['name'] as String,
    ownerId: map['ownerId'] as String,
    inviteCode: map['inviteCode'] as String?,
  );

  Map<String, dynamic> toMap() => {
    'name': name,
    'ownerId': ownerId,
    'inviteCode': inviteCode,
  };
}

/// 팀원 한 명. "내 팀 목록"도 이 문서로 만든다 (컬렉션 그룹 쿼리).
///
/// Firestore: teams/{teamId}/members/{uid}
class Membership {
  const Membership({
    required this.teamId,
    required this.teamName,
    required this.uid,
    required this.displayName,
    required this.role,
  });

  final String teamId;

  /// 팀 목록 표시용 사본.
  final String teamName;
  final String uid;
  final String displayName;
  final TeamRole role;

  factory Membership.fromMap(String teamId, Map<String, dynamic> map) =>
      Membership(
        teamId: teamId,
        teamName: map['teamName'] as String,
        uid: map['uid'] as String,
        displayName: map['displayName'] as String? ?? '',
        role: TeamRole.values.byName(map['role'] as String),
      );

  Map<String, dynamic> toMap() => {
    'teamName': teamName,
    'uid': uid,
    'displayName': displayName,
    'role': role.name,
  };

  Membership withRole(TeamRole role) => Membership(
    teamId: teamId,
    teamName: teamName,
    uid: uid,
    displayName: displayName,
    role: role,
  );
}

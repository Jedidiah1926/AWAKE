import 'dart:async';

import '../models/annotation.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/team.dart';
import 'backend.dart';

/// Firebase 없이 메모리에서 도는 백엔드. 데모 모드와 테스트에 쓴다.
/// 앱을 끄면 데이터가 사라진다.
class MemoryBackend {
  MemoryBackend();

  final _changes = StreamController<void>.broadcast();
  var _nextId = 1;

  final _users = <String, ({String password, AppUser user})>{};
  final _teams = <String, Team>{};
  final _members = <String, Map<String, Membership>>{}; // teamId → uid →
  final _invites = <String, String>{}; // code → teamId
  final _songs = <String, Map<String, Song>>{};
  final _setlists = <String, Map<String, Setlist>>{};
  final _annotations = <String, Map<String, Annotation>>{}; // teamId/scoreId

  late final auth = _MemoryAuth(this);
  late final teams = _MemoryTeamDirectory(this);
  final _teamData = <String, _MemoryTeamData>{};

  Backend toBackend() => Backend(
    auth: auth,
    teams: teams,
    teamData: (teamId) =>
        _teamData.putIfAbsent(teamId, () => _MemoryTeamData(this, teamId)),
    isDemo: true,
  );

  String _id(String prefix) => '$prefix${_nextId++}';

  void _notify() => _changes.add(null);

  /// 현재 값을 먼저 내보내고, 데이터가 바뀔 때마다 다시 계산해서 내보낸다.
  Stream<T> _watch<T>(T Function() read) => Stream.multi((controller) {
    controller.add(read());
    final sub = _changes.stream.listen((_) => controller.add(read()));
    // Future를 돌려주지 않는다. 돌려주면 flutter_test의 가짜 시간 환경에서
    // Stream.first 이후의 await가 멈춘다.
    controller.onCancel = () {
      sub.cancel();
    };
  });

  /// 데모 계정의 비밀번호. 로그아웃한 뒤 다시 들어올 때 쓴다.
  static const demoPassword = 'demo1234';

  /// 데모용 계정, 팀, 곡을 만들고 그 계정으로 로그인한다.
  Future<void> seedDemo(AppUser user, {required List<Song> songs}) async {
    _users[user.email!] = (password: demoPassword, user: user);
    final team = await teams.createTeam(name: '데모 찬양팀', owner: user);
    final data = toBackend().teamData(team.teamId);
    for (final song in songs) {
      await data.saveSong(song);
    }
    auth.signInAs(user);
  }
}

class _MemoryAuth implements AuthService {
  _MemoryAuth(this._b);

  final MemoryBackend _b;
  final _controller = StreamController<AppUser?>.broadcast();
  AppUser? _current;

  @override
  AppUser? get currentUser => _current;

  @override
  Stream<AppUser?> userChanges() => Stream.multi((c) {
    c.add(_current);
    final sub = _controller.stream.listen(c.add);
    c.onCancel = () {
      sub.cancel();
    };
  });

  void _set(AppUser? user) {
    _current = user;
    _controller.add(user);
  }

  @override
  Future<AppUser> signIn({
    required String email,
    required String password,
  }) async {
    final entry = _b._users[email.trim().toLowerCase()];
    if (entry == null || entry.password != password) {
      throw const AppException('이메일 또는 비밀번호가 맞지 않습니다.');
    }
    _set(entry.user);
    return entry.user;
  }

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final key = email.trim().toLowerCase();
    if (_b._users.containsKey(key)) {
      throw const AppException('이미 가입된 이메일입니다.');
    }
    if (password.length < 6) {
      throw const AppException('비밀번호는 6자 이상이어야 합니다.');
    }
    final user = AppUser(
      uid: _b._id('user'),
      displayName: displayName.trim(),
      email: key,
    );
    _b._users[key] = (password: password, user: user);
    _set(user);
    return user;
  }

  /// 데모 모드에서 로그인 화면 없이 바로 들어갈 때 쓴다.
  void signInAs(AppUser user) => _set(user);

  @override
  Future<void> signOut() async => _set(null);
}

class _MemoryTeamDirectory implements TeamDirectory {
  _MemoryTeamDirectory(this._b);

  final MemoryBackend _b;

  @override
  Stream<List<Membership>> watchMyTeams(String uid) => _b._watch(
    () =>
        [for (final members in _b._members.values) ?members[uid]]
          ..sort((a, b) => a.teamName.compareTo(b.teamName)),
  );

  @override
  Stream<Team?> watchTeam(String teamId) => _b._watch(() => _b._teams[teamId]);

  @override
  Stream<List<Membership>> watchMembers(String teamId) => _b._watch(
    () =>
        [...?_b._members[teamId]?.values]
          ..sort((a, b) => a.displayName.compareTo(b.displayName)),
  );

  @override
  Future<Membership> createTeam({
    required String name,
    required AppUser owner,
  }) async {
    final id = _b._id('team');
    final code = generateInviteCode();
    _b._teams[id] = Team(
      id: id,
      name: name.trim(),
      ownerId: owner.uid,
      inviteCode: code,
    );
    _b._invites[code] = id;
    final member = Membership(
      teamId: id,
      teamName: name.trim(),
      uid: owner.uid,
      displayName: owner.displayName,
      role: TeamRole.leader,
    );
    _b._members[id] = {owner.uid: member};
    _b._notify();
    return member;
  }

  @override
  Future<Membership> joinTeam({
    required String code,
    required AppUser user,
  }) async {
    final teamId = _b._invites[normalizeInviteCode(code)];
    final team = teamId == null ? null : _b._teams[teamId];
    if (team == null) throw const AppException('초대 코드를 찾을 수 없습니다.');
    final members = _b._members[team.id]!;
    if (members[user.uid] case final existing?) return existing;
    final member = Membership(
      teamId: team.id,
      teamName: team.name,
      uid: user.uid,
      displayName: user.displayName,
      role: TeamRole.member,
    );
    members[user.uid] = member;
    _b._notify();
    return member;
  }

  @override
  Future<String> regenerateInviteCode(String teamId) async {
    final team = _b._teams[teamId]!;
    _b._invites.remove(team.inviteCode);
    final code = generateInviteCode();
    _b._invites[code] = teamId;
    _b._teams[teamId] = Team(
      id: team.id,
      name: team.name,
      ownerId: team.ownerId,
      inviteCode: code,
    );
    _b._notify();
    return code;
  }

  @override
  Future<void> setRole(Membership member, TeamRole role) async {
    _b._members[member.teamId]![member.uid] = member.withRole(role);
    _b._notify();
  }

  @override
  Future<void> removeMember(Membership member) async {
    _b._members[member.teamId]!.remove(member.uid);
    _b._notify();
  }
}

class _MemoryTeamData implements TeamData {
  _MemoryTeamData(this._b, this.teamId);

  final MemoryBackend _b;

  @override
  final String teamId;

  Map<String, Song> get _songs => _b._songs.putIfAbsent(teamId, () => {});
  Map<String, Setlist> get _setlists =>
      _b._setlists.putIfAbsent(teamId, () => {});
  Map<String, Annotation> _annotations(String scoreId) =>
      _b._annotations.putIfAbsent('$teamId/$scoreId', () => {});

  @override
  Stream<List<Song>> watchSongs() => _b._watch(
    () => _songs.values.toList()..sort((a, b) => a.title.compareTo(b.title)),
  );

  @override
  Future<Song?> getSong(String songId) async => _songs[songId];

  @override
  String newSongId() => _b._id('song');

  @override
  Future<void> saveSong(Song song) async {
    _songs[song.id] = song;
    _b._notify();
  }

  @override
  Future<void> deleteSong(String songId) async {
    _songs.remove(songId);
    _b._notify();
  }

  @override
  Stream<List<Setlist>> watchSetlists({int limit = 20}) => _b._watch(
    () => (_setlists.values.toList()..sort((a, b) => b.date.compareTo(a.date)))
        .take(limit)
        .toList(),
  );

  @override
  Stream<Setlist?> watchSetlist(String setlistId) =>
      _b._watch(() => _setlists[setlistId]);

  @override
  String newSetlistId() => _b._id('setlist');

  @override
  Future<void> saveSetlist(Setlist setlist) async {
    _setlists[setlist.id] = setlist;
    _b._notify();
  }

  @override
  Future<void> deleteSetlist(String setlistId) async {
    _setlists.remove(setlistId);
    _b._notify();
  }

  @override
  Stream<List<Annotation>> watchAnnotations(String scoreId, String uid) =>
      _b._watch(
        () => [
          for (final a in _annotations(scoreId).values)
            if (a.visibility == AnnotationVisibility.team || a.authorId == uid)
              a,
        ],
      );

  @override
  String newAnnotationId(String scoreId) => _b._id('annotation');

  @override
  Future<void> saveAnnotation(String scoreId, Annotation annotation) async {
    _annotations(scoreId)[annotation.id] = annotation;
    _b._notify();
  }

  @override
  Future<void> deleteAnnotation(String scoreId, String annotationId) async {
    _annotations(scoreId).remove(annotationId);
    _b._notify();
  }
}

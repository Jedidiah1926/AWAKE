import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/annotation.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/team.dart';
import 'backend.dart';

/// Firebase(Auth + Firestore) 백엔드.
///
/// 경로 구조 (firestore.rules와 맞춰야 함):
/// - invites/{code}                         { teamId, teamName, createdBy }
/// - teams/{teamId}                         Team
/// - teams/{teamId}/members/{uid}           Membership
/// - teams/{teamId}/songs/{songId}          Song
/// - teams/{teamId}/setlists/{setlistId}    Setlist
/// - teams/{teamId}/scores/{scoreId}/annotations/{annotationId}
Backend firebaseBackend({FirebaseAuth? auth, FirebaseFirestore? firestore}) {
  final db = firestore ?? FirebaseFirestore.instance;
  final data = <String, FirestoreTeamData>{};
  return Backend(
    auth: FirebaseAuthService(auth ?? FirebaseAuth.instance),
    teams: FirestoreTeamDirectory(db),
    teamData: (teamId) =>
        data.putIfAbsent(teamId, () => FirestoreTeamData(teamId, db)),
  );
}

// ── 로그인 ─────────────────────────────────────────────

class FirebaseAuthService implements AuthService {
  FirebaseAuthService(this._auth);

  final FirebaseAuth _auth;

  AppUser? _toUser(User? user) => user == null
      ? null
      : AppUser(
          uid: user.uid,
          displayName: user.displayName ?? user.email?.split('@').first ?? '',
          email: user.email,
        );

  @override
  AppUser? get currentUser => _toUser(_auth.currentUser);

  @override
  Stream<AppUser?> userChanges() => _auth.userChanges().map(_toUser);

  @override
  Future<AppUser> signIn({required String email, required String password}) =>
      _guard(() async {
        final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );
        return _toUser(cred.user)!;
      });

  @override
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  }) => _guard(() async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await cred.user!.updateDisplayName(displayName.trim());
    await cred.user!.reload();
    return _toUser(_auth.currentUser)!;
  });

  @override
  Future<void> signOut() => _auth.signOut();

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on FirebaseAuthException catch (e) {
      throw AppException(switch (e.code) {
        'invalid-credential' ||
        'user-not-found' ||
        'wrong-password' => '이메일 또는 비밀번호가 맞지 않습니다.',
        'email-already-in-use' => '이미 가입된 이메일입니다.',
        'weak-password' => '비밀번호는 6자 이상이어야 합니다.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'network-request-failed' => '인터넷 연결을 확인해 주세요.',
        'too-many-requests' => '시도가 너무 많습니다. 잠시 후 다시 해 주세요.',
        _ => '로그인 오류: ${e.message ?? e.code}',
      });
    }
  }
}

// ── 팀 ─────────────────────────────────────────────────

class FirestoreTeamDirectory implements TeamDirectory {
  FirestoreTeamDirectory(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _teams =>
      _db.collection('teams');
  CollectionReference<Map<String, dynamic>> get _invites =>
      _db.collection('invites');

  Membership _member(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Membership.fromMap(doc.reference.parent.parent!.id, doc.data()!);

  /// 컬렉션 그룹 쿼리. firestore.indexes.json의 members.uid 설정이 필요하다.
  @override
  Stream<List<Membership>> watchMyTeams(String uid) => _db
      .collectionGroup('members')
      .where('uid', isEqualTo: uid)
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) _member(d)]
              ..sort((a, b) => a.teamName.compareTo(b.teamName)),
      );

  @override
  Stream<Team?> watchTeam(String teamId) => _teams
      .doc(teamId)
      .snapshots()
      .map((d) => d.exists ? Team.fromMap(d.id, d.data()!) : null);

  @override
  Stream<List<Membership>> watchMembers(String teamId) => _teams
      .doc(teamId)
      .collection('members')
      .snapshots()
      .map(
        (s) =>
            [for (final d in s.docs) _member(d)]
              ..sort((a, b) => a.displayName.compareTo(b.displayName)),
      );

  /// 팀, 리더 멤버, 초대 코드를 한 번에 쓴다 (보안 규칙이 이 묶음을 검사한다).
  @override
  Future<Membership> createTeam({
    required String name,
    required AppUser owner,
  }) async {
    final teamRef = _teams.doc();
    final code = generateInviteCode();
    final member = Membership(
      teamId: teamRef.id,
      teamName: name.trim(),
      uid: owner.uid,
      displayName: owner.displayName,
      role: TeamRole.leader,
    );
    final batch = _db.batch()
      ..set(teamRef, {
        ...Team(
          id: teamRef.id,
          name: name.trim(),
          ownerId: owner.uid,
          inviteCode: code,
        ).toMap(),
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(teamRef.collection('members').doc(owner.uid), member.toMap())
      ..set(_invites.doc(code), {
        'teamId': teamRef.id,
        'teamName': name.trim(),
        'createdBy': owner.uid,
      });
    await batch.commit();
    return member;
  }

  @override
  Future<Membership> joinTeam({
    required String code,
    required AppUser user,
  }) async {
    final normalized = normalizeInviteCode(code);
    if (normalized.isEmpty) throw const AppException('초대 코드를 입력해 주세요.');
    final invite = await _invites.doc(normalized).get();
    if (!invite.exists) throw const AppException('초대 코드를 찾을 수 없습니다.');
    final teamId = invite['teamId'] as String;

    final memberRef = _teams.doc(teamId).collection('members').doc(user.uid);
    final existing = await memberRef.get();
    if (existing.exists) return _member(existing);

    final member = Membership(
      teamId: teamId,
      teamName: invite['teamName'] as String,
      uid: user.uid,
      displayName: user.displayName,
      role: TeamRole.member,
    );
    // inviteCode는 보안 규칙이 참여 자격을 확인하는 데 쓴다.
    await memberRef.set({...member.toMap(), 'inviteCode': normalized});
    return member;
  }

  @override
  Future<String> regenerateInviteCode(String teamId) async {
    final teamRef = _teams.doc(teamId);
    final team = Team.fromMap(teamId, (await teamRef.get()).data()!);
    final code = generateInviteCode();
    final batch = _db.batch()
      ..set(_invites.doc(code), {
        'teamId': teamId,
        'teamName': team.name,
        'createdBy': team.ownerId,
      })
      ..update(teamRef, {'inviteCode': code});
    if (team.inviteCode != null) batch.delete(_invites.doc(team.inviteCode));
    await batch.commit();
    return code;
  }

  @override
  Future<void> setRole(Membership member, TeamRole role) => _teams
      .doc(member.teamId)
      .collection('members')
      .doc(member.uid)
      .update({'role': role.name});

  @override
  Future<void> removeMember(Membership member) =>
      _teams.doc(member.teamId).collection('members').doc(member.uid).delete();
}

// ── 팀 데이터 ──────────────────────────────────────────

class FirestoreTeamData implements TeamData {
  FirestoreTeamData(this.teamId, FirebaseFirestore db)
    : _team = db.collection('teams').doc(teamId);

  @override
  final String teamId;
  final DocumentReference<Map<String, dynamic>> _team;

  CollectionReference<Map<String, dynamic>> get _songs =>
      _team.collection('songs');
  CollectionReference<Map<String, dynamic>> get _setlists =>
      _team.collection('setlists');

  @override
  Stream<List<Song>> watchSongs() => _songs
      .orderBy('title')
      .snapshots()
      .map((s) => [for (final d in s.docs) Song.fromMap(d.id, d.data())]);

  @override
  Future<Song?> getSong(String songId) async {
    final doc = await _songs.doc(songId).get();
    return doc.exists ? Song.fromMap(doc.id, doc.data()!) : null;
  }

  @override
  String newSongId() => _songs.doc().id;

  @override
  Future<void> saveSong(Song song) => _songs.doc(song.id).set(song.toMap());

  @override
  Future<void> deleteSong(String songId) => _songs.doc(songId).delete();

  @override
  Stream<List<Setlist>> watchSetlists({int limit = 20}) => _setlists
      .orderBy('date', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => [for (final d in s.docs) Setlist.fromMap(d.id, d.data())]);

  /// 콘티 하나를 실시간으로 본다. 인도자가 키나 순서를 바꾸면 바로 반영된다.
  @override
  Stream<Setlist?> watchSetlist(String setlistId) => _setlists
      .doc(setlistId)
      .snapshots()
      .map((d) => d.exists ? Setlist.fromMap(d.id, d.data()!) : null);

  @override
  String newSetlistId() => _setlists.doc().id;

  @override
  Future<void> saveSetlist(Setlist setlist) =>
      _setlists.doc(setlist.id).set(setlist.toMap());

  @override
  Future<void> deleteSetlist(String setlistId) =>
      _setlists.doc(setlistId).delete();

  CollectionReference<Map<String, dynamic>> _annotations(String scoreId) =>
      _team.collection('scores').doc(scoreId).collection('annotations');

  /// [uid]가 볼 수 있는 주석 (팀 공유 + 내 개인 주석)을 실시간으로 본다.
  ///
  /// 보안 규칙이 쿼리 단위로 검사되므로, 두 조건을 각각 쿼리하고 합친다.
  @override
  Stream<List<Annotation>> watchAnnotations(String scoreId, String uid) {
    final shared = _annotations(scoreId)
        .where('visibility', isEqualTo: AnnotationVisibility.team.name)
        .snapshots();
    final mine = _annotations(scoreId)
        .where('authorId', isEqualTo: uid)
        .where('visibility', isEqualTo: AnnotationVisibility.private.name)
        .snapshots();
    return _combine(shared, mine).map(
      (pair) => [
        for (final snap in pair)
          for (final d in snap.docs) Annotation.fromMap(d.id, d.data()),
      ],
    );
  }

  @override
  String newAnnotationId(String scoreId) => _annotations(scoreId).doc().id;

  /// 펜을 뗄 때(획 단위) 한 번씩 호출한다.
  @override
  Future<void> saveAnnotation(String scoreId, Annotation annotation) =>
      _annotations(scoreId).doc(annotation.id).set(annotation.toMap());

  @override
  Future<void> deleteAnnotation(String scoreId, String annotationId) =>
      _annotations(scoreId).doc(annotationId).delete();
}

/// 두 스트림의 최신 값을 함께 내보낸다.
Stream<List<T>> _combine<T>(Stream<T> a, Stream<T> b) {
  late StreamController<List<T>> controller;
  StreamSubscription<T>? subA, subB;
  T? lastA, lastB;
  var hasA = false, hasB = false;

  void emit() {
    if (hasA && hasB) controller.add([lastA as T, lastB as T]);
  }

  controller = StreamController<List<T>>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}

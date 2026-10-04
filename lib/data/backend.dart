import 'dart:math';

import '../models/annotation.dart';
import '../models/setlist.dart';
import '../models/song.dart';
import '../models/team.dart';

/// 로그인한 사용자.
class AppUser {
  const AppUser({required this.uid, required this.displayName, this.email});

  final String uid;
  final String displayName;
  final String? email;
}

/// 로그인/회원가입. Firebase Auth 또는 메모리 구현.
abstract interface class AuthService {
  AppUser? get currentUser;
  Stream<AppUser?> userChanges();

  Future<AppUser> signIn({required String email, required String password});
  Future<AppUser> signUp({
    required String email,
    required String password,
    required String displayName,
  });
  Future<void> signOut();
}

/// 로그인, 회원가입 실패 등 사용자에게 보여줄 오류.
class AppException implements Exception {
  const AppException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 팀 목록, 팀 만들기, 참여, 멤버 관리.
abstract interface class TeamDirectory {
  /// 내가 속한 팀들.
  Stream<List<Membership>> watchMyTeams(String uid);

  Stream<Team?> watchTeam(String teamId);
  Stream<List<Membership>> watchMembers(String teamId);

  /// 팀을 만들고 만든 사람을 리더로 등록한다. 초대 코드도 같이 만든다.
  Future<Membership> createTeam({required String name, required AppUser owner});

  /// 초대 코드로 팀에 멤버로 참여한다.
  Future<Membership> joinTeam({required String code, required AppUser user});

  /// 초대 코드를 새로 만든다 (이전 코드는 더 이상 쓸 수 없음).
  Future<String> regenerateInviteCode(String teamId);

  Future<void> setRole(Membership member, TeamRole role);
  Future<void> removeMember(Membership member);
}

/// 팀 하나의 곡, 콘티, 주석.
abstract interface class TeamData {
  String get teamId;

  Stream<List<Song>> watchSongs();
  Future<Song?> getSong(String songId);
  String newSongId();
  Future<void> saveSong(Song song);
  Future<void> deleteSong(String songId);

  Stream<List<Setlist>> watchSetlists({int limit = 20});
  Stream<Setlist?> watchSetlist(String setlistId);
  String newSetlistId();
  Future<void> saveSetlist(Setlist setlist);
  Future<void> deleteSetlist(String setlistId);

  Stream<List<Annotation>> watchAnnotations(String scoreId, String uid);
  String newAnnotationId(String scoreId);
  Future<void> saveAnnotation(String scoreId, Annotation annotation);
  Future<void> deleteAnnotation(String scoreId, String annotationId);
}

/// 앱 전체에서 쓰는 백엔드 묶음.
class Backend {
  const Backend({
    required this.auth,
    required this.teams,
    required this.teamData,
    this.isDemo = false,
  });

  final AuthService auth;
  final TeamDirectory teams;
  final TeamData Function(String teamId) teamData;

  /// Firebase 없이 메모리에서 도는 모드.
  final bool isDemo;
}

/// 헷갈리는 글자(0/O, 1/I/L)를 뺀 8자리 초대 코드.
String generateInviteCode([Random? random]) {
  const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  final r = random ?? Random.secure();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

/// 사용자가 입력한 초대 코드를 정리한다 (공백, 하이픈 제거, 대문자).
String normalizeInviteCode(String input) =>
    input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();

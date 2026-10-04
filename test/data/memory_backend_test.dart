import 'package:awake/core/music/progression.dart';
import 'package:awake/data/backend.dart';
import 'package:awake/data/memory_backend.dart';
import 'package:awake/features/setlist/format.dart';
import 'package:awake/models/song.dart';
import 'package:awake/models/team.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late MemoryBackend memory;
  late Backend backend;

  setUp(() {
    memory = MemoryBackend();
    backend = memory.toBackend();
  });

  test('가입, 로그아웃, 로그인', () async {
    final user = await backend.auth.signUp(
      email: 'Lead@Church.org',
      password: 'secret1',
      displayName: '인도자',
    );
    expect(backend.auth.currentUser?.uid, user.uid);

    await backend.auth.signOut();
    expect(backend.auth.currentUser, isNull);

    await expectLater(
      backend.auth.signIn(email: 'lead@church.org', password: 'wrong!'),
      throwsA(isA<AppException>()),
    );
    final again = await backend.auth.signIn(
      email: ' lead@church.org ',
      password: 'secret1',
    );
    expect(again.uid, user.uid);
  });

  test('같은 이메일로 두 번 가입할 수 없다', () async {
    await backend.auth.signUp(
      email: 'a@b.c',
      password: 'secret1',
      displayName: 'A',
    );
    expect(
      backend.auth.signUp(
        email: 'a@b.c',
        password: 'secret1',
        displayName: 'B',
      ),
      throwsA(isA<AppException>()),
    );
  });

  test('팀 만들기 → 초대 코드로 참여 → 역할 변경 → 내보내기', () async {
    final leader = await backend.auth.signUp(
      email: 'l@x.y',
      password: 'secret1',
      displayName: '리더',
    );
    final created = await backend.teams.createTeam(
      name: ' 청년부 ',
      owner: leader,
    );
    expect(created.role, TeamRole.leader);
    expect(created.teamName, '청년부');

    final team = await backend.teams.watchTeam(created.teamId).first;
    final code = team!.inviteCode!;
    expect(code, hasLength(8));

    final singer = await backend.auth.signUp(
      email: 's@x.y',
      password: 'secret1',
      displayName: '싱어',
    );
    // 소문자, 하이픈이 섞여도 참여된다.
    final joined = await backend.teams.joinTeam(
      code: '${code.substring(0, 4).toLowerCase()}-${code.substring(4)}',
      user: singer,
    );
    expect(joined.role, TeamRole.member);
    expect(joined.teamId, created.teamId);

    // 다시 참여해도 중복으로 들어가지 않는다.
    await backend.teams.joinTeam(code: code, user: singer);
    expect(
      await backend.teams.watchMembers(created.teamId).first,
      hasLength(2),
    );

    final mine = await backend.teams.watchMyTeams(singer.uid).first;
    expect(mine.single.teamName, '청년부');

    await backend.teams.setRole(joined, TeamRole.editor);
    final members = await backend.teams.watchMembers(created.teamId).first;
    expect(
      members.firstWhere((m) => m.uid == singer.uid).role,
      TeamRole.editor,
    );

    await backend.teams.removeMember(joined);
    expect(await backend.teams.watchMyTeams(singer.uid).first, isEmpty);
  });

  test('없는 초대 코드, 새로 만든 뒤 이전 코드', () async {
    final leader = await backend.auth.signUp(
      email: 'l@x.y',
      password: 'secret1',
      displayName: '리더',
    );
    final created = await backend.teams.createTeam(name: '팀', owner: leader);
    final old =
        (await backend.teams.watchTeam(created.teamId).first)!.inviteCode!;
    final fresh = await backend.teams.regenerateInviteCode(created.teamId);
    expect(fresh, isNot(old));

    expect(
      backend.teams.joinTeam(code: old, user: leader),
      throwsA(isA<AppException>()),
    );
    expect(
      backend.teams.joinTeam(code: 'NOPE1234', user: leader),
      throwsA(isA<AppException>()),
    );
  });

  test('곡 목록은 실시간으로 갱신된다', () async {
    final data = backend.teamData('t1');
    final updates = <List<String>>[];
    final sub = data.watchSongs().listen(
      (songs) => updates.add([for (final s in songs) s.title]),
    );
    await data.saveSong(const Song(id: 'b', title: '나중 곡', originalKey: 'G'));
    await data.saveSong(const Song(id: 'a', title: '가나다 곡', originalKey: 'A'));
    await data.deleteSong('b');
    await pumpEventQueue();
    await sub.cancel();

    expect(updates, [
      <String>[],
      ['나중 곡'],
      ['가나다 곡', '나중 곡'],
      ['가나다 곡'],
    ]);
  });

  group('helpers', () {
    test('초대 코드', () {
      final code = generateInviteCode();
      expect(code, matches(RegExp(r'^[A-Z2-9]{8}$')));
      expect(code, isNot(contains(RegExp('[01OIL]'))));
      expect(normalizeInviteCode(' abcd-efgh '), 'ABCDEFGH');
    });

    test('코드 진행 입력', () {
      expect(splitProgression('G D/F# | Em7, C'), ['G', 'D/F#', 'Em7', 'C']);
      expect(splitProgression('  '), isEmpty);
      expect(invalidChords(['G', '주님', 'Em7', 'x']), ['주님', 'x']);
      expect(formatProgression(['G', 'C']), '| G | C |');
      expect(formatProgression([]), '');
    });

    test('다가오는 일요일', () {
      expect(nextSunday(DateTime(2026, 10, 4, 15)), DateTime(2026, 10, 4));
      expect(nextSunday(DateTime(2026, 10, 5)), DateTime(2026, 10, 11));
      expect(nextSunday(DateTime(2026, 10, 10)), DateTime(2026, 10, 11));
      expect(formatDate(DateTime(2026, 10, 4)), '2026. 10. 4. (일)');
    });
  });
}

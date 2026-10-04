import 'package:awake/app/app.dart';
import 'package:awake/core/music/music_key.dart';
import 'package:awake/data/backend.dart';
import 'package:awake/data/memory_backend.dart';
import 'package:awake/models/team.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> enter(WidgetTester tester, String label, String text) async {
    await tester.enterText(find.widgetWithText(TextFormField, label), text);
  }

  Future<void> setSize(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('가입 → 팀 만들기 → 곡 등록 → 콘티 작성 → 조 바꾸기 (넓은 화면)', (tester) async {
    await setSize(tester, const Size(1200, 900));
    final backend = MemoryBackend().toBackend();
    await tester.pumpWidget(AwakeApp(backend: backend));
    await tester.pumpAndSettle();

    // 회원가입
    await tester.tap(find.text('처음이에요 (회원가입)'));
    await tester.pumpAndSettle();
    await enter(tester, '이름', '김인도');
    await enter(tester, '이메일', 'lead@church.org');
    await enter(tester, '비밀번호', 'secret1');
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    // 팀 만들기
    expect(find.textContaining('아직 속한 팀이 없습니다'), findsOneWidget);
    await tester.tap(find.text('팀 만들기'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '청년부 찬양팀');
    await tester.tap(find.text('만들기'));
    await tester.pumpAndSettle();

    // 넓은 화면은 왼쪽 레일
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.textContaining('아직 콘티가 없습니다'), findsOneWidget);

    // 곡 등록
    await tester.tap(find.text('곡').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('곡 추가'));
    await tester.pumpAndSettle();
    await enter(tester, '제목', '주 품에');
    await enter(tester, '인트로 코드 (원래 조 기준)', 'G D/F# Em7 C');
    await tester.pumpAndSettle();
    // 넓은 화면은 편집과 미리보기가 나란히
    expect(find.text('| G | D/F# | Em7 | C |'), findsOneWidget);
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('주 품에'), findsOneWidget);

    // 콘티 작성
    await tester.tap(find.text('콘티').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('새 콘티'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, '곡 추가'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('주 품에').last);
    await tester.pumpAndSettle();
    expect(find.text('1. 주 품에'), findsOneWidget);

    // G → A
    await tester.tap(find.byType(DropdownButton<MusicKey>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Intro | A | E/G# | F#m7 | D |'),
      findsOneWidget,
    );

    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    expect(find.text('주일 예배'), findsOneWidget);
    expect(find.textContaining('1곡 · A'), findsOneWidget);

    // 콘티 보기 → 곡 열기
    await tester.tap(find.text('주일 예배'));
    await tester.pumpAndSettle();
    expect(find.text('Intro | A | E/G# | F#m7 | D |'), findsOneWidget);
    await tester.tap(find.text('주 품에'));
    await tester.pumpAndSettle();
    expect(find.textContaining('원래 조 G → A'), findsOneWidget);
    expect(find.text('| A | E/G# | F#m7 | D |'), findsOneWidget);
  });

  testWidgets('초대 코드로 참여한 멤버는 보기만 할 수 있다 (좁은 화면)', (tester) async {
    await setSize(tester, const Size(400, 800));
    final memory = MemoryBackend();
    final backend = memory.toBackend();

    // 리더가 미리 팀과 콘티 준비
    final leader = await backend.auth.signUp(
      email: 'l@x.y',
      password: 'secret1',
      displayName: '리더',
    );
    final team = await backend.teams.createTeam(name: '주일 찬양팀', owner: leader);
    final code =
        (await backend.teams.watchTeam(team.teamId).first)!.inviteCode!;
    await backend.auth.signOut();

    await tester.pumpWidget(AwakeApp(backend: backend));
    await tester.pumpAndSettle();
    await tester.tap(find.text('처음이에요 (회원가입)'));
    await tester.pumpAndSettle();
    await enter(tester, '이름', '박싱어');
    await enter(tester, '이메일', 's@x.y');
    await enter(tester, '비밀번호', 'secret1');
    await tester.tap(find.text('가입하기'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('초대 코드로 참여'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), code.toLowerCase());
    await tester.tap(find.text('참여'));
    await tester.pumpAndSettle();

    // 좁은 화면은 아래 탭, 멤버는 편집 버튼이 없다
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('새 콘티'), findsNothing);
    await tester.tap(find.text('곡'));
    await tester.pumpAndSettle();
    expect(find.text('곡 추가'), findsNothing);

    // 팀 탭: 역할 확인, 초대 코드는 리더만 보임
    await tester.tap(find.text('팀'));
    await tester.pumpAndSettle();
    expect(find.text('내 역할: 멤버'), findsOneWidget);
    expect(find.text('초대 코드'), findsNothing);

    // 리더가 편집자로 바꾸면 바로 편집 버튼이 생긴다
    final me = (await backend.teams.watchMembers(team.teamId).first).firstWhere(
      (m) => m.displayName == '박싱어',
    );
    await backend.teams.setRole(me, TeamRole.editor);
    await tester.pumpAndSettle();
    expect(find.text('내 역할: 편집자'), findsOneWidget);
    await tester.tap(find.text('곡'));
    await tester.pumpAndSettle();
    expect(find.text('곡 추가'), findsOneWidget);

    // 리더가 내보내면 팀 목록으로 돌아간다
    await backend.teams.removeMember(me.withRole(TeamRole.editor));
    await tester.pumpAndSettle();
    expect(find.textContaining('아직 속한 팀이 없습니다'), findsOneWidget);
  });

  testWidgets('데모 모드는 예제 팀과 곡으로 시작한다', (tester) async {
    final memory = MemoryBackend();
    await memory.seedDemo(
      const AppUser(uid: 'demo', displayName: '데모', email: 'demo@awake.app'),
      songs: const [],
    );
    await tester.pumpWidget(AwakeApp(backend: memory.toBackend()));
    await tester.pumpAndSettle();
    expect(find.text('데모 찬양팀'), findsOneWidget);

    // 로그아웃 후 데모 계정으로 다시 로그인
    await tester.tap(find.byTooltip('로그아웃'));
    await tester.pumpAndSettle();
    expect(find.textContaining('데모 모드'), findsOneWidget);
    await enter(tester, '이메일', 'demo@awake.app');
    await enter(tester, '비밀번호', MemoryBackend.demoPassword);
    await tester.tap(find.text('로그인'));
    await tester.pumpAndSettle();
    expect(find.text('데모 찬양팀'), findsOneWidget);
  });
}

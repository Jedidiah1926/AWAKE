import 'dart:async';

import 'package:flutter/material.dart';

import '../data/backend.dart';
import '../features/auth/sign_in_screen.dart';
import '../features/team/team_home_screen.dart';
import '../features/team/team_select_screen.dart';
import '../models/team.dart';
import 'scope.dart';

/// 앱 최상단. 로그인 상태와 선택한 팀에 따라 화면을 고른다.
///
/// 로그인 전 → 로그인 화면
/// 팀 선택 전 → 팀 목록 (만들기 / 참여)
/// 팀 선택 후 → 팀 홈 (콘티, 곡, 팀)
class AwakeApp extends StatefulWidget {
  const AwakeApp({super.key, required this.backend});

  final Backend backend;

  @override
  State<AwakeApp> createState() => _AwakeAppState();
}

class _AwakeAppState extends State<AwakeApp> {
  StreamSubscription<AppUser?>? _authSub;
  StreamSubscription<List<Membership>>? _teamsSub;

  AppUser? _user;
  var _authReady = false;
  List<Membership> _teams = const [];

  String? _selectedTeamId;

  /// 방금 만들거나 참여한 팀. 내 팀 목록 스트림에 아직 안 들어왔을 수 있다.
  Membership? _pending;

  @override
  void initState() {
    super.initState();
    _authSub = widget.backend.auth.userChanges().listen(_onUser);
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _teamsSub?.cancel();
    super.dispose();
  }

  void _onUser(AppUser? user) {
    final changed = user?.uid != _user?.uid;
    setState(() {
      _authReady = true;
      _user = user;
      if (changed) {
        _teams = const [];
        _selectedTeamId = null;
        _pending = null;
      }
    });
    if (!changed) return;
    _teamsSub?.cancel();
    _teamsSub = user == null
        ? null
        : widget.backend.teams.watchMyTeams(user.uid).listen(_onTeams);
  }

  void _onTeams(List<Membership> teams) {
    setState(() {
      _teams = teams;
      if (_pending != null && teams.any((t) => t.teamId == _pending!.teamId)) {
        _pending = null;
      }
      // 팀에서 내보내졌으면 팀 목록으로.
      if (_selectedTeamId != null &&
          _pending == null &&
          !teams.any((t) => t.teamId == _selectedTeamId)) {
        _selectedTeamId = null;
      }
    });
  }

  Membership? get _membership {
    for (final t in _teams) {
      if (t.teamId == _selectedTeamId) return t;
    }
    return _pending?.teamId == _selectedTeamId ? _pending : null;
  }

  void _select(Membership m) => setState(() {
    _selectedTeamId = m.teamId;
    if (!_teams.any((t) => t.teamId == m.teamId)) _pending = m;
  });

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final membership = _membership;

    final Widget home;
    if (!_authReady) {
      home = const Scaffold(body: Center(child: CircularProgressIndicator()));
    } else if (user == null) {
      home = const SignInScreen();
    } else if (membership == null) {
      home = TeamSelectScreen(user: user, onSelect: _select);
    } else {
      home = TeamHomeScreen(
        onSwitchTeam: () => setState(() => _selectedTeamId = null),
      );
    }

    return BackendScope(
      backend: widget.backend,
      child: MaterialApp(
        // 로그인 사용자나 팀이 바뀌면 화면 스택을 처음부터 다시 만든다.
        key: ValueKey('${user?.uid}/${membership?.teamId}'),
        title: 'AWAKE',
        theme: ThemeData(colorSchemeSeed: Colors.indigo),
        darkTheme: ThemeData(
          colorSchemeSeed: Colors.indigo,
          brightness: Brightness.dark,
        ),
        // 모든 화면(푸시한 화면 포함)에서 TeamScope를 쓸 수 있게 Navigator 위에 둔다.
        builder: (context, child) => user == null || membership == null
            ? child!
            : TeamScope(
                user: user,
                membership: membership,
                data: widget.backend.teamData(membership.teamId),
                child: child!,
              ),
        home: home,
      ),
    );
  }
}
